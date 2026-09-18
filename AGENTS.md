# AGENTS.md

推进门锁：`docs/agents/PROCESS.md`
模型表：`docs/agents/MODELS.md`
词典：`CONTEXT.md`
决策：`docs/adr/`

编码与目录规范。不要把当前票号、mode、template 写进本文件。

## Git

- 默认分支：`main`
- 分支：`feat/<issue>-<slug>` / `fix/<issue>-<slug>`
- 提交：`type(scope): subject`，scope = 模块名；需要时正文 `Fixes #<n>`
- type：`feat` `fix` `docs` `refactor` `test` `chore`
- 不要直提交默认分支；不要 `--force` 推共享分支；不要提交密钥、构建产物

## 目录

浅目录，路径跟 contains 节点。不要造层目录。

Godot 工程根在仓库根：`project.godot` 属 `boot`。模块目录：`boot/` `player/` `arsenal/` `hostiles/` `stages/` `audio/`。测试在 `tests/<模块>/`。

## 码风

**GDScript：** 跟 Godot 官方风格。缩进用 tab。命名 `snake_case`。不要写 3D 节点或场景。改到哪种语言就按那种。

## 注释

公开 API 必须有文档注释。不要复述下一行代码。不要写行号。

GDScript：公开函数、信号、导出属性用 `##` 文档注释。

## 构建

- 命令：Godot 4.7.2 标准版（GDScript，不要 .NET）。主机测试 `godot --headless --path . -s res://tests/run.gd`。Windows 桌面导出，产物不提交。
- 产物不提交
