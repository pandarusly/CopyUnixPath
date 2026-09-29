# CopyUnixPath

在 Windows 上开发、代码跑在 Linux 服务器或容器里时，"复制文件地址"拿到的是 `D:\project\weights\model.pt` 这种路径，贴进脚本前得手工改成 `/weights/model.pt`，改多了烦，还容易改错。

CopyUnixPath 把这一步变成一次右键，转换好的 Unix 风格路径直接进剪贴板。单文件 Win32 C++，约 120 行，无界面，静态链接，无运行时依赖。

## 用法

右键任意文件或文件夹 → **Copy Unix Path**，结果已在剪贴板，Ctrl+V 即可。

命令行同样可以调用：

```
CopyUnixPath.exe "C:\data\train.csv"
```

不带参数运行直接退出，不修改剪贴板。

## 转换流程

1. 去掉首尾引号
2. 按 ini 规则做路径替换（在反斜杠形态上匹配）
3. 反斜杠 `\` → 正斜杠 `/`
4. 写入剪贴板

## 安装

1. 取得 `CopyUnixPath.exe`（从 [Release](../../releases) 下载，或运行 `build.ps1` 本地编译），放到一个固定目录，同目录再放一份 `CopyUnixPath.ini`
2. 注册右键菜单：

```powershell
.\install.ps1                        # 注册到当前用户，不需要管理员
.\install.ps1 -AllUsers              # 注册到所有用户，需要管理员
.\install.ps1 -Uninstall             # 清掉两处的注册项
.\install.ps1 -Uninstall -AllUsers   # 只清机器级那条，需要管理员
```

`install.ps1` 取脚本所在目录的 exe 路径写进注册表，参数为 `"%V"`，所以文件和文件夹右键都有这个菜单项。

菜单项有两个可能的位置，机器级 `HKLM\Software\Classes\AllFilesystemObjects\shell\CopyUnixPath`
和用户级 `HKCU\Software\Classes\...`。Windows 把两者合并成 `HKEY_CLASSES_ROOT`，
同一个键路径以用户级为准，所以用户级会遮住机器级，不会多出一个菜单项；
`-Uninstall` 默认两处一起清，否则被遮住的那条会在可见的那条被删掉后悄悄生效。

手工注册（注册表编辑器）：

```
HKEY_CURRENT_USER\Software\Classes\AllFilesystemObjects\shell\CopyUnixPath
    (默认)          = Copy Unix Path
    \command
        (默认)      = "<安装目录>\CopyUnixPath.exe" "%V"
```

## 配置文件

`CopyUnixPath.ini`，放在 exe 同目录。仓库跟踪的是 `CopyUnixPath.ini.example`，本机的 `CopyUnixPath.ini` 不入库（`build.ps1` 在缺失时会自动从 example 复制一份）。

```ini
[Rules]
Rule1=匹配串>替换串
Rule2=匹配串>替换串
```

- 匹配串：Windows 路径片段，使用反斜杠 `\`
- 替换串：目标路径
- `>` 为分隔符

### 示例

`CopyUnixPath.ini.example` 的内容与实测结果：

| 输入 | 输出 |
|---|---|
| `C:\data\train.csv` | `/mnt/data/train.csv` |
| `D:\project\weights\model.pt` | `/weights/model.pt` |
| `D:\project\logs\train.log` | `/logs/train.log` |
| `D:\project\src\main.py` | `/workspace/src/main.py` |
| `E:\code\app\main.py` | `/code/app/main.py` |
| `C:\Users\me\notes.txt` | `C:/Users/me/notes.txt` |

最后一行是没命中任何规则的情况：只做斜杠转换。

## 实现说明

- **规则读 ini，不写死在代码里**：映射跟机器绑定，写死的话换台机器就要重编译。规则按顺序依次应用，更具体的路径必须排在更泛的前面，否则会被泛规则先命中（`D:\project\logs` 必须排在 `D:\project` 之前）
- **每条规则只替换第一次匹配**：路径里重复出现的匹配串保持原样，`C:\data\a\C:\data` → `/mnt/data/a/C:/data`
- **剪贴板内存所有权**：`SetClipboardData` 成功后内存归系统管，不能再 `GlobalFree`；只有调用失败时才需要自己释放
- **全程宽字符 API**：`CommandLineToArgvW` 取命令行、`GetPrivateProfileStringW` 读 ini、`CF_UNICODETEXT` 写剪贴板；混用多字节版本的话中文路径会乱码
- **静默失败**：`OpenClipboard` 失败时直接返回，不提示也不报错

## 编译

```powershell
.\build.ps1
```

等价于：

```
clang++ -o CopyUnixPath.exe src/CopyUnixPath.cpp -Os -fno-exceptions -fno-rtti -DNDEBUG -static -lshell32 -luser32 -lkernel32
```

输出 114688 字节（112 KB），`clang++ 21.1.0`（target `x86_64-pc-windows-msvc`）实测通过。仓库不含 exe，需要时本地编译或从 Release 下载。

## 发布

推送 `v*` 形式的 tag 会触发 `.github/workflows/build.yml`，在 windows-latest 上编译并把 `CopyUnixPath.exe`、`CopyUnixPath.ini` 挂到 Release：

```
git tag v1.0.0
git push origin v1.0.0
```

## 目录结构

```
CopyUnixPath/
├─ .github/workflows/build.yml   编译，打 tag 时发布 Release
├─ src/CopyUnixPath.cpp          全部源码
├─ CopyUnixPath.ini.example      规则示例
├─ CopyUnixPath.ini              本机规则，不进仓库
├─ build.ps1                     编译
├─ install.ps1                   注册 / 注销右键菜单
├─ LICENSE                       MIT
└─ README.md
```

## License

MIT
