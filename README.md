# 前后双摄同屏 App — 使用与安装说明

一个原生 iOS App：前置 + 后置摄像头**同屏显示**，可点按交换主/副画面、双摄同时拍照存相册、后置手电筒。

代码在 `DualCam/` 目录，云编译配置在 `DualCam/.github/workflows/build.yml`。

---

## 一、先看清限制（务必阅读）

| 项目 | 说明 |
|---|---|
| 机型要求 | 需要 iPhone XS / XR 及更新机型（A12 芯片起），iOS 14.0 以上。旧机型不支持双摄同时工作，App 会给出提示。 |
| Windows 不能编译 | iPhone App 必须在 macOS + Xcode 编译。本方案用 GitHub 的免费云编译完成，你无需 Mac。 |
| 不能直接安装 | 我无法接触你的手机。最后一步需你用数据线把手机连到 Windows 电脑，用工具签名安装。 |
| 免费签名 7 天过期 | 免费 Apple ID 签名有效期 7 天，到期需连电脑重签一次。**建议用一个专门的小号 Apple ID**，不要用主号。 |
| 设备数量限制 | 一个免费 Apple ID 最多同时给 3 个 App 签名。 |

> 这些是苹果生态的硬性规则，任何"免重签/永久安装"的说法都不可信。

---

## 二、准备三个账号 / 软件（一次性）

1. **GitHub 账号**（免费）：https://github.com —— 用来云编译。
2. **Apple ID**（建议小号，需知道密码 + 开启双重认证）：用来签名。
3. **Windows 电脑**上先安装：
   - **iTunes 桌面版**（必须从苹果官网下载的安装版，**不要用 Microsoft Store 版**）：https://www.apple.com/itunes/download/
   - **iCloud 桌面版**（同样官网版）：https://support.apple.com/zh-cn/HT204283
   - **Sideloadly**（签名安装工具，Windows 版）：https://sideloadly.io/ → 下载 Windows 版安装
   - 一条**原装或 MFi 数据线**

> 说明：Sideloadly 依赖苹果官网版 iTunes 的驱动。如果之前装的是商店版，先卸载再装官网版。

---

## 三、上传代码到 GitHub（一次性）

1. 打开 https://github.com → 右上角 **+ → New repository**。
2. Repository name 填 `DualCam`（或任意英文名）。
3. 选择 **Public**（公共仓库云编译免费且不限额；Private 每月只有 2000 分钟且 macOS 按 10 倍扣，容易不够）。
4. **不要**勾选 "Add a README file" 等任何初始化选项，直接 **Create repository**。
5. 进入仓库页面，点 **uploading an existing file**（或 Add file → Upload files）。
6. 把我给你的 **`DualCam` 整个文件夹里的所有文件和子文件夹**（包括 `.github` 文件夹、`Sources` 文件夹、`project.yml`）全部拖进去上传。
   - 注意：`.github` 是隐藏文件夹，拖整个 `DualCam` 目录最简单，不要漏掉它，否则云编译不会触发。
7. 底部 **Commit changes** 提交。

---

## 四、触发云编译，拿到 IPA 安装包

1. 代码上传后，云编译会**自动触发**（因为 workflow 配了 push 触发）。
   - 也可以手动触发：点仓库顶部 **Actions** 标签 → 左侧选 **Build 前后双摄 IPA** → 右侧 **Run workflow → Run workflow**。
2. 等待编译（首次约 2–5 分钟）。点击正在运行的任务可看实时日志。
3. 编译成功后，进入这次运行详情页面，拉到最底部 **Artifacts** 区域，找到 **DualCam-IPA**，点击下载。
4. 下载得到一个 zip，解压后就是 **`DualCam.ipa`**（这就是 iPhone 安装包）。

> 如果任务显示红色失败：点进去看日志最后的红色报错，把报错文字发给我，我帮你改代码。

---

## 五、用 Sideloadly 签名并安装到 iPhone

1. Windows 上打开 **Sideloadly**（首次运行按提示登录/授权）。
2. iPhone 用数据线连电脑，手机上弹出"信任此电脑？"→ 点 **信任**，输入锁屏密码。
3. Sideloadly 顶部设备栏应显示你的 iPhone 名称和系统版本。
4. 把 `DualCam.ipa` **拖进** Sideloadly 窗口（或点 IPA 图标选择文件）。
5. 在 **Apple Account** 栏填你的 Apple ID（完整邮箱格式；手机号注册的先去 appleid.apple.com 查登录邮箱）。
6. 点 **Start**。
   - 弹出密码框：输入 Apple ID 密码。
   - 开了双重认证的，验证码会弹在你手机上，**直接接在密码后面一起输入**（例如 `password123456`）。
7. 等待进度走完，出现 **Done / Installing 100%**。期间手机保持解锁、不要拔线。
8. 首次安装后，需要在 iPhone 上做两件事：
   - **信任证书**：设置 → 通用 → **VPN 与设备管理**（或"描述文件与设备管理"）→ 在"开发者 App"下点你的 Apple ID → **信任**。
   - **开发者模式**（iOS 16+）：设置 → 隐私与安全性 → **开发者模式** → 打开 → 按提示重启手机并确认。
9. 回到主屏幕，就能看到"双摄同屏"图标，点开即可使用。

---

## 六、7 天到期后怎么续签

到期后 App 会打不开。续签不用重新找包、不用重新信任：

1. 手机连电脑，打开 Sideloadly。
2. 拖入**同一个** `DualCam.ipa`，填**同一个** Apple ID，点 **Start**，密码 + 验证码。
3. 完成后有效期重新计算 7 天，数据不丢。

> 小技巧：首次有线连接成功后，可在 iTunes 里开启"通过 Wi-Fi 与此 iPhone 同步"（设备摘要 → 选项），之后 Sideloadly 可无线识别，续签不用插线。Sideloadly 也有自动刷新（auto refresh）选项，但需电脑保持开机且安装其守护进程。

---

## 七、常见问题

- **签名报 `Guru Meditation` / 证书错误**：Sideloadly 里打开 Advanced Options，切换 Anisette 的本地/远程模式，重启软件再试。
- **填 Apple ID 报 404 / 登录失败**：确认填的是完整邮箱（不是手机号）；确认开了双重认证；换用最新版 Sideloadly。
- **识别不到设备**：换原装数据线、重新插拔、重开 Sideloadly；确认装的是官网版 iTunes。
- **装完打不开**：多半是没信任证书或没开开发者模式，回到第五步第 8 点检查。
- **App 提示"此设备不支持双摄"**：机型太老（非 A12 及以上），无解，只能换较新 iPhone。
- **编译失败**：把 GitHub Actions 日志里的红色报错发给我，我帮你修正代码。

---

## 八、技术说明（给感兴趣的人）

- 双摄核心：`AVCaptureMultiCamSession`（iOS 13+），前后各一路 `AVCaptureDeviceInput`（`addInputWithNoConnections`），各自建立到预览层和 `AVCapturePhotoOutput` 的连接。
- 拍照：点击快门时同时调用两个 photo output，把两张照片分别存入相册。
- 为控制硬件开销，两路视频格式限制在 1280 宽度以内。
- 最低系统 iOS 14.0，纯 UIKit + AVFoundation，无第三方依赖，便于云编译一次通过。
