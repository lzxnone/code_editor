import 'package:re_highlight/re_highlight.dart';

/// Minecraft Function (.mcfunction) 语法高亮定义
/// 基于 Modrinth 官方/社区主流 better-highlightjs-mcfunction 规范转译，
/// 完美适配 re_highlight 引擎与 Android 移动端高性能只读/编辑渲染。
final Mode langMcfunction = Mode(
  refs: {},
  name: 'Minecraft Function',
  aliases: ['mcfunction', 'mcf'],
  caseInsensitive: true,
  contains: <Mode>[
    // 1. 注释行与行内注释 (# ...)
    HASH_COMMENT_MODE,

    // 2. 字符串字面量（支持单引号与双引号转义）
    Mode(
      scope: 'string',
      variants: <Mode>[
        Mode(
          begin: '"',
          end: '"',
          contains: <Mode>[
            Mode(begin: '""'),
            BACKSLASH_ESCAPE,
          ],
        ),
        Mode(
          begin: "'",
          end: "'",
          contains: <Mode>[
            Mode(begin: "''"),
            BACKSLASH_ESCAPE,
          ],
        ),
      ],
    ),

    // 3. 宏变量 $(variable) - Minecraft 1.20.2+ 原生命令宏
    Mode(
      scope: 'variable',
      begin: r'\$\([a-zA-Z_][a-zA-Z0-9_]*\)',
    ),

    // 4. 目标实体选择器 (@p, @a, @e, @s, @r) 及条件方括号 [@e[type=zombie,distance=..10]]
    Mode(
      scope: 'variable',
      begin: r'@[apers](?:\[[^\]\r\n]*\])?',
    ),

    // 5. 标准实体与数据 UUID
    Mode(
      scope: 'number',
      begin: r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
    ),

    // 6. 命名空间与资源标识符 (minecraft:stone, #minecraft:arrows, custom:item/weapon)
    Mode(
      scope: 'symbol',
      begin: r'#?[a-z0-9_.-]+:[a-z0-9_./-]+',
    ),

    // 7. 相对坐标与视线坐标 (~, ^, ~10, ^-0.5)
    Mode(
      scope: 'symbol',
      begin: r'(?:~|\^)(?:-?\d*(?:\.\d+)?)?',
    ),

    // 8. Minecraft 数字字面量与类型后缀 (10b, 1.5f, 1000L, 0.5d, 2s)
    Mode(
      scope: 'number',
      begin: r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[bB|dD|fF|lL|sS])?(?![a-zA-Z0-9_.])',
    ),

    // 9. 顶级核心命令关键字
    Mode(
      scope: 'keyword',
      begin: r'(?:^|\s)(?:advancement|attribute|ban|ban-ip|banlist|bossbar|clear|clone|damage|data|datapack|debug|defaultgamemode|deop|difficulty|effect|enchant|execute|experience|fill|fillbiome|forceload|function|gamemode|gamerule|give|help|item|jfr|kick|kill|list|locate|loot|me|msg|op|pardon|pardon-ip|particle|perf|place|playsound|publish|recipe|reload|return|ride|save-all|save-off|save-on|say|schedule|scoreboard|seed|setblock|setidletimeout|setworldspawn|spawnpoint|spectate|spreadplayers|stop|stopsound|summon|tag|team|teammsg|teleport|tell|tellraw|test|tick|time|title|tm|tp|transfer|trigger|w|weather|whitelist|worldborder|xp)(?=\s|$)',
    ),

    // 10. execute / data / scoreboard 等高频子命令关键字
    Mode(
      scope: 'built_in',
      begin: r'\b(?:run|as|at|positioned|align|facing|rotated|in|anchored|if|unless|store|block|blocks|entity|score|matches|storage|result|success|eyes|feet|add|remove|set|get|merge|modify|query|reset|enable|operation)\b',
    ),

    // 11. 布尔字面量
    Mode(
      scope: 'literal',
      begin: r'\b(?:true|false)\b',
    ),

    // 12. 记分板与计算运算符
    Mode(
      scope: 'operator',
      begin: r'(=|\+=|-=|\*=|/=|%=|<|>|><|<=|>=)',
    ),
  ],
);
