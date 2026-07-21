# Translator

[English](README.md) | 简体中文

基于 SwiftUI、AppKit (`NSPanel`) 和 LM Studio 运行的极简本地 macOS 翻译助手，并支持本地离线语音转写、实时中英双语字幕和离线文本朗读（TTS）。

---

## 📋 系统要求与运行环境

为了使应用能够正常运行及成功编译，请确保您的系统和开发环境满足以下条件：

### 1. 系统版本要求
*   **macOS 15.0 (Sequoia) 或更高版本**：应用中的实时双语字幕功能依赖 macOS 15 引入的原生 `Translation` 框架以及最新的 SwiftUI 渲染引擎。

### 2. 开发与编译环境
*   **Xcode 26.0 或更高版本** / **Swift 6.0 编译工具链**：用于支持 Swift 6 严格并发检查（Strict Concurrency）以及现代语言特性编译。

### 3. 翻译后端服务 (LM Studio 或兼容服务)
*   **本地模型服务运行中**：主翻译界面依赖本地运行的 LLM 后端。
    *   **API 基准地址**：`http://localhost:1234/v1`（默认，可在应用设置中自定义）
    *   **模型名称**：`local-model`（默认，自动路由至当前加载的模型，或可在设置中下拉直接指定）
    *   请在测试翻译前确保您的本地模型服务已开启并成功加载模型。

### 4. 离线翻译模型包 (实时字幕必备)
*   实时双语字幕依赖系统内置的离线翻译引擎。为了确保离线转译正常运行，请前往 **系统设置 > 通用 > 语言与地区 > 翻译语言** (System Settings > General > Language & Region > Translation Languages)，提前下载安装 **“英语”** 和 **“中文（简体）”** 的离线翻译包。

---

## ✨ 功能特性

- **本地与云端大模型翻译：** 既支持本地运行的 LM Studio / Ollama 作为免 Key 模型后端，也支持通过配置 API Key 直连包括 DeepSeek 在内的标准 OpenAI 兼容的云端 API。
- **详解模式 (新)：** 深度拆解输入的词汇或短语。输入英文时，提供多个中文释义、单单词的词性、以及高质量双语例句（不输出音标）；输入中文时，提供多个英文候选翻译、具体语境释义差异、以及双语对照例句。内容全部通过 Markdown 在 UI 中完美进行分行与排版渲染。
- **云端 API 鉴权支持：** 支持在设置中输入可选的 API Key，请求时自动在 Header 中附带 `Authorization: Bearer <API_KEY>`，完美适配云端 DeepSeek 等平台的鉴权体系。
- **离线语音朗读 (TTS)：** 支持对输入源文本与翻译结果进行双向本地语音朗读，并配有播放状态的动态高亮动效。
- **自动语种识别：** 利用 `NaturalLanguage` 框架自动判定文本语种（英文/中文），并智能切换对应的男/女声音频输出。
- **浮动输入视窗 (类似 Spotlight)：** 全局快捷键唤醒，默认居中且在输入时自适应向下延展，失焦自动隐退。
- **自定义全局热键：** 集成 `KeyboardShortcuts`，支持用户在设置中自定义全局唤醒快捷键。
- **实时双语字幕 (新)：** 捕获系统扬声器音轨，在本地离线将英文语音转写为文本，并实时生成中文翻译。字幕窗口支持鼠标拖拽移动、边缘任意拉伸缩放，并自带鼠标移出自动半透明的渐隐效果。

---

## 🚀 编译与调试

### 1. 使用 Xcode 运行
1. 打开 Xcode。
2. 选择菜单栏 `File > Open...` 并选中本项目根目录或 `Package.swift`。
3. 等待 Swift Package 依赖解析完成。
4. 在上方 Scheme 列表中选择 `Translator` 和 `My Mac`。
5. 点击 `Run` (或按 `Cmd + R`) 运行。

应用运行后会作为状态栏图标小工具存在。使用默认快捷键 `Control + Space` 可唤起主翻译面板。

### 2. 命令行开发
```bash
swift build
swift test
```

---

## 📦 生产发布包构建 (DMG)

项目版本在 [`VERSION`](VERSION) 文件中进行管理，构建脚本支持符合 `主版本.子版本.修订号+构建号`（例如 `1.2.1+4`）的格式。

### 1. 本地打包发布流程

```bash
chmod +x scripts/release_dmg.sh
./scripts/release_dmg.sh
```

### 2. 手动指定版本号与构建号
```bash
./scripts/release_dmg.sh 1.2.1 4
```

打包完成后，生成的安装产物会存放在项目根目录下的 `dist/` 目录中：
*   `dist/Translator.app` (应用包)
*   `dist/Translator.dmg` (安装镜像盘)

### 3. 可选：附带开发者签名打包
```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release_dmg.sh
```

---

## 🎹 键盘快捷键说明

*   `Control + Space`（默认）：唤醒或隐藏主翻译面板。
*   `Enter`：提交/发送文本进行翻译。
*   `Shift + Enter`：在输入框内插入换行符而不触发提交。
*   `Escape`：隐藏主翻译面板（同时会自动终止当前正在播放的朗读音频）。

## ⚙️ 应用配置与设置

您可以点击状态栏图标菜单中的 **Settings...** 打开配置面板：

*   **API Base URL (API 基准地址)**：配置模型服务的连接地址（LM Studio 默认使用 `http://localhost:1234/v1`，也完美支持 Ollama、自定义端口等，或配置为云端 DeepSeek 的地址 `https://api.deepseek.com`）。
*   **API Key (API 密钥)**：为需要鉴权的云端 API 服务（如 DeepSeek 等）配置 API Key，将安全地以 Bearer Token 形式发送请求。
*   **Model Selection (模型选择)**：点击刷新按钮会自动查询服务端 (`GET /v1/models`) 以获取当前已加载或可用的模型列表，允许您显式指定使用哪一个模型。
*   **Temperature (温度)**：控制文本生成随机性/创意度（默认为 `0.2`）。
*   **模型思考/推理过滤**：本应用会自动在 UI 层面清洗掉返回内容中的 `<think>...</think>` 以及 `<thought>...</thought>` 标签块，确保不论模型是否进行思考，展示在界面的翻译结果都是绝对纯净的。

## 📝 开发备注
*   应用在启动时会通过将激活策略设置为 `.accessory` 来隐藏其 Dock 栏图标，使其完全作为后台小工具运行。
*   `Sources/Translator/Resources/Info.plist` 是为今后若要将本 Swift Package 转化为标准 Xcode 完整 App 工程而预留的支持性文件。

---

## 📄 授权协议
本项目基于 [MIT](LICENSE) 协议开源。
