# Daily Better 上架前清单

更新时间：2026-03-21

## 当前项目已具备
- App 名称：Daily Better
- Bundle ID：com.guoxl.DailyBetter
- 版本号：1.0.0 (1)
- 已完成模拟器构建与运行验证
- 已生成 iPhone 截图
- 已生成 iPad 截图
- 已准备元数据草稿：`Metadata.md`
- 已准备隐私政策草稿：`PrivacyPolicy.md`
- 已准备支持页草稿：`Support.md`
- 已准备可发布网页：`Web/privacy.html` 和 `Web/support.html`
- App 内已加入反馈邮箱入口

## 明天必须准备好的
- 一个可公开访问的 Support URL
- 一个可公开访问的 Privacy Policy URL
- App Review 联系人姓名、邮箱、手机号
- 你的 Apple Developer Team 选择结果
- 最终确认是否保留 iPad 支持

## App Store Connect 必填
- 创建或打开 `Daily Better` 的 App 记录
- 填写 App 名称、副标题、描述、关键词、版权信息
- 填写 Support URL
- 填写 Privacy Policy URL
- 填写 App Review 联系人信息
- 完成年龄分级问卷
- 完成 App Privacy 问卷
- 上传至少 1 张 iPhone 截图
- 如果保留 iPad 支持，上传至少 1 张 iPad 截图

## 建议你直接这样填写
- Category：Health & Fitness
- App Privacy：基于当前代码，选择 `No, we do not collect data from this app`
- App Review Notes：
  - No sign-in required.
  - All user entries are stored on-device.
  - Notifications are optional reminders only.
- 年龄分级：按实际内容如实填写，这版通常会比较低

## Xcode 侧操作
1. 打开 `DailyBetter.xcodeproj`
2. 选择你的 Apple Developer Team
3. 确认 Bundle Identifier 不需要再改
4. 确认版本号 `1.0.0` 和 build `1`
5. 选择 `Any iOS Device`
6. 执行 `Product > Archive`
7. 在 Organizer 里执行上传

## 上传后要做的
- 等待 build 处理完成
- 在 App Store Connect 里选择刚上传的 build
- 补完所有元数据和问卷
- 再提交审核

## 容易漏掉的点
- Support URL 不能只是空页面，最好有邮箱或联系方式
- Privacy Policy URL 必须可公开访问
- 如果 App Store Connect 提示 `Missing Compliance`，补答 export compliance
- 如果你准备在欧盟上架，检查是否需要填写 DSA trader status

## 和这版项目最相关的判断
- 这版没有登录
- 这版没有第三方分析 SDK
- 这版没有后端账号体系
- 这版核心数据保存在本地设备
- 这版只请求通知权限，不涉及更高风险权限

## 时间提醒
- 截至 2026-03-21，这次提交仍可使用当前 Xcode 16.4 流程
- 但从 2026-04-28 开始，上传到 App Store Connect 的 app 必须使用 Xcode 26+ 和 iOS 26 SDK+
