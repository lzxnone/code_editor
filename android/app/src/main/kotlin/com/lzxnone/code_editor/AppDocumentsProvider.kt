package com.lzxnone.code_editor

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException

/**
 * Storage Access Framework (SAF) DocumentsProvider.
 *
 * 直接将应用内部私有 `files` 目录映射为系统文档存储盘，
 * 支持 MT 管理器等外部文件管理器免 Root 直接挂载、浏览、编辑、创建与删除内部私有文件（如 Linux 容器与项目代码）。
 */
class AppDocumentsProvider : DocumentsProvider() {

    companion object {
        private const val ROOT_ID = "code_editor_files_root"

        private val DEFAULT_ROOT_PROJECTION = arrayOf(
            DocumentsContract.Root.COLUMN_ROOT_ID,
            DocumentsContract.Root.COLUMN_DOCUMENT_ID,
            DocumentsContract.Root.COLUMN_TITLE,
            DocumentsContract.Root.COLUMN_SUMMARY,
            DocumentsContract.Root.COLUMN_FLAGS,
            DocumentsContract.Root.COLUMN_ICON,
            DocumentsContract.Root.COLUMN_AVAILABLE_BYTES
        )

        private val DEFAULT_DOCUMENT_PROJECTION = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_FLAGS,
            DocumentsContract.Document.COLUMN_SIZE
        )
    }

    private lateinit var baseDir: File

    override fun onCreate(): Boolean {
        val ctx = context ?: return false
        // 直接严格映射 files 目录
        baseDir = ctx.filesDir
        if (!baseDir.exists()) {
            baseDir.mkdirs()
        }
        return true
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_ROOT_PROJECTION)
        val row = result.newRow()
        row.add(DocumentsContract.Root.COLUMN_ROOT_ID, ROOT_ID)
        row.add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, getDocIdForFile(baseDir))
        row.add(DocumentsContract.Root.COLUMN_TITLE, "CodeEditor")
        row.add(DocumentsContract.Root.COLUMN_SUMMARY, "files")
        row.add(
            DocumentsContract.Root.COLUMN_FLAGS,
            DocumentsContract.Root.FLAG_SUPPORTS_CREATE or
            DocumentsContract.Root.FLAG_SUPPORTS_IS_CHILD or
            DocumentsContract.Root.FLAG_LOCAL_ONLY
        )
        row.add(DocumentsContract.Root.COLUMN_ICON, R.mipmap.ic_launcher)
        row.add(DocumentsContract.Root.COLUMN_AVAILABLE_BYTES, baseDir.freeSpace)
        return result
    }

    override fun queryDocument(documentId: String?, projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val file = getFileForDocId(documentId)
        includeFile(result, file)
        return result
    }

    override fun queryChildDocuments(
        parentDocumentId: String?,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val parent = getFileForDocId(parentDocumentId)
        parent.listFiles()?.forEach { file ->
            includeFile(result, file)
        }
        return result
    }

    override fun openDocument(
        documentId: String?,
        mode: String?,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = getFileForDocId(documentId)
        val accessMode = ParcelFileDescriptor.parseMode(mode)
        return ParcelFileDescriptor.open(file, accessMode)
    }

    override fun createDocument(
        parentDocumentId: String?,
        mimeType: String?,
        displayName: String?
    ): String {
        val parent = getFileForDocId(parentDocumentId)
        val file = File(parent, displayName ?: "unnamed")
        if (DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
            if (!file.mkdir() && !file.isDirectory) {
                throw FileNotFoundException("无法创建目录: ${file.path}")
            }
        } else {
            if (!file.createNewFile() && !file.isFile) {
                throw FileNotFoundException("无法创建文件: ${file.path}")
            }
        }
        return getDocIdForFile(file)
    }

    override fun deleteDocument(documentId: String?) {
        val file = getFileForDocId(documentId)
        if (!file.deleteRecursively()) {
            throw FileNotFoundException("无法删除: ${file.path}")
        }
    }

    override fun renameDocument(documentId: String?, displayName: String?): String? {
        if (displayName == null) throw FileNotFoundException("新名称不能为空")
        val file = getFileForDocId(documentId)
        val target = File(file.parentFile, displayName)
        if (!file.renameTo(target)) {
            throw FileNotFoundException("重命名失败: ${file.path} -> ${target.path}")
        }
        return getDocIdForFile(target)
    }

    override fun isChildDocument(parentDocumentId: String?, documentId: String?): Boolean {
        val parent = getFileForDocId(parentDocumentId)
        val child = getFileForDocId(documentId)
        return child.canonicalPath.startsWith(parent.canonicalPath)
    }

    private fun getFileForDocId(docId: String?): File {
        if (docId == null) throw FileNotFoundException("DocId 不能为空")
        val file = File(docId)
        if (!file.exists()) {
            throw FileNotFoundException("文件不存在: ${file.path}")
        }
        return file
    }

    private fun getDocIdForFile(file: File): String {
        return file.absolutePath
    }

    private fun includeFile(result: MatrixCursor, file: File) {
        val row = result.newRow()
        row.add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, getDocIdForFile(file))
        row.add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, file.name)
        row.add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, file.lastModified())
        row.add(DocumentsContract.Document.COLUMN_SIZE, file.length())

        var flags = DocumentsContract.Document.FLAG_SUPPORTS_DELETE or
                    DocumentsContract.Document.FLAG_SUPPORTS_RENAME

        if (file.isDirectory) {
            flags = flags or DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE
            row.add(DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.MIME_TYPE_DIR)
        } else {
            flags = flags or DocumentsContract.Document.FLAG_SUPPORTS_WRITE
            val mime = getMimeType(file)
            row.add(DocumentsContract.Document.COLUMN_MIME_TYPE, mime)
        }
        row.add(DocumentsContract.Document.COLUMN_FLAGS, flags)
    }

    private fun getMimeType(file: File): String {
        val ext = file.extension
        return if (ext.isNotEmpty()) {
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase()) ?: "application/octet-stream"
        } else {
            "application/octet-stream"
        }
    }
}
