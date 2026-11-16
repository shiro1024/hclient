## Development Guidelines

- 始终以磁盘上的实际文件为工作和验证依据，不以 Git 暂存区内容替代磁盘状态。
- 没有用户明确授权，禁止执行 `git add`、`git commit`、`git restore`、`git reset`、`git checkout`、`git stash`、`git clean`、`git rm`、`git mv`、`git push` 等修改 Git 状态或历史的操作。开发、修复、评审和交付任务不构成这些操作的授权；授权仅适用于用户明确指定的操作与范围。
- 不检查暂存区状态，不运行 `git status`、`git diff --cached`、`git diff --staged`、`git ls-files --stage` 等命令。
- 实现与评审应覆盖实际调用链。已确认设计未要求的门禁、版本锁定、hash 锁定和版本声明，必须先论证用途与成本收益；没有充分依据就不添加。
- 性能调整以真实样本和实际操作成本为依据，不提前限制内存、线程或文件大小。临时测试、probe 和一次性执行脚本用完删除，正式回归测试保留。
- 开发和下载不添加 proxy。`.context/` 保存本地设计、任务与调研记录，排除在提交之外。

### Project And Commands

hclient 是基于 JHenTai 的 Flutter 客户端，浏览 E-Hentai / EXHentai，支持 Android、iOS、Windows、macOS。包名为 `shiro.hclient`，不提供 Linux 产品。版本及 SDK 要求以 `pubspec.yaml` 为准。

```bash
flutter pub get
flutter run -t lib/src/main.dart
flutter analyze
flutter test

# 修改 Drift 表、查询或 DAO 后重新生成
dart run build_runner build

# 数据库开发期间按需使用
dart run build_runner watch --delete-conflicting-outputs

# 在 native 目录执行，使该目录的工具链配置生效
cd native
cargo test --lib
```

按改动范围验证。模块开发期间运行相关测试，阶段收尾由主 agent 统筹整体检查；已有有效证据继续复用。测试覆盖下载、存储导入、副本恢复、WebDAV 同步、路径兼容和阅读布局。

### Dart Code Organization

- UI 优先采用 Material 标准组件、主题颜色、排版和交互；只有具体需求或规范未定义时才定制样式。

- `lib/src/main.dart` 是入口，注册生命周期 bean，按 `initDependencies` 拓扑排序后初始化，再运行应用。
- GetX 负责状态、路由、依赖和翻译。页面通常由 `*_page.dart`、`*_logic.dart`、`*_state.dart` 组成；`GetBuilder` 通过 `update()` 刷新，需要跨视图广播的设置使用 `.obs`。
- `BasePageLogic` 位于 `pages/base/`，统一列表分页、刷新、搜索及屏蔽；具体页面实现 `getGalleryPage()`。
- 路由统一定义在 `routes/routes.dart`。`EHPage.side` 控制平板左右分栏，`offAllBefore` 控制右侧页面栈，设置路由沿用 `settingPrefix`。
- `pages/layout/` 包含 `mobile_v2`、`tablet_v2`、`desktop`，由首页按布局选择。共享组件位于 `widget/`，应用级包装为 `app_manager.dart`。
- `service/` 存放服务，`setting/` 存放设置单例；模型、枚举、扩展和公共工具分别位于 `model/`、`enum/`、`extension/`、`utils/`。
- `config/` 管理主题和应用配置，`mixin/` 管理页面共享行为，`exception/` 定义业务异常。
- `l18n/` 使用 `LocaleText`。新增语言同时更新语言文件、`locale_text.dart` 和 `locale_consts.dart`；新增文案沿用现有翻译键。

### Lifecycle And Storage

- 服务和设置实现 `service/jh_service.dart` 中的 `JHLifeCircleBean`。新增 bean 要注册到入口列表，并声明实际依赖。
- `JHLifeCircleBeanErrorCatch` 的子类实现 `doInitBean()` / `doAfterBeanReady()`。`JHLifeCircleBeanWithConfigStorage` 通过 `applyBeanConfig()` / `toConfigString()` 将设置保存到 `local_config`。
- Drift 数据库入口为 `database/database.dart`，全局实例是 `appDb`；表与 DAO 分别位于 `database/table/`、`database/dao/`。当前磁盘实现为 schema v4，后续变更增加 `MigrationStrategy.onUpgrade` 步骤并重新生成 `database.g.dart`。
- `local_content_service.dart` 管理本地副本、页输入、替换和退休；`content_sync/` 管理页引用及 SQLite manifest；`gallery_sync/` 管理上传、云端索引、恢复和清理。
- `content_page_download_service.dart` 统一已下载页替换及恢复；`download_relocation_service.dart` 协调迁移、退休时各下载入口的取消与收束。
- `gallery_download/` 与 `archive_download_service.dart` 是逐图下载和归档入口；`local_gallery_service.dart` 扫描本地内容；`path_service.dart` 解析平台目录。
- `tag_translation_service.dart` 管理标签翻译，`local_block_rule_service.dart` 管理屏蔽规则，`first_run_service.dart` 管理首次启动默认项；历史、阅读进度和快捷搜索沿用各自服务。
- `local_backup_service.dart` 提供本地与 WebDAV 共用的备份格式；WebDAV 客户端及配置备份位于 `service/webdav/`，连接设置为 `webdav_setting.dart`。
- `cloud_service.dart` 保留五类分享数据的导入导出语义。历史格式兼容按实际导入消费者维护，一次性迁移不混入正常下载和同步链路。

### Network And Logging

- `network/EHRequest` 负责站点请求、Cookie、缓存及 EX 域名前置；`JHRequest` 提供后端配置等接口；`ArchiveBotRequest` 保留归档 Bot 接入。HTML 解析位于 `utils/eh_spider_parser.dart`。
- Dio 使用项目配置的 fork；依赖来源以 `pubspec.yaml` 为准。图片与阅读使用 `extended_image`、`photo_view` / `zoom_view`；桌面 Cookie 登录使用 `desktop_webview_window`。
- 使用全局 `log`（`service/log.dart`）记录日志，输出到控制台及详细、警告、下载日志文件。调用现有的 `trace`、`debug`、`info`、`warning`、`error`、`download` 方法；生命周期 mixin 已记录初始化异常。

## Rust Code Organization

- `native/` 是同应用构建发布的文件编解码 adapter，使用 crates.io precomp2 公开 API 和 zstd；Dart 通过窄 C ABI 调用，构建入口是 `hook/build.dart`。
- `native/src/lib.rs` 承载文件与 FFI 边界，`page_codec.rs` 承载编码格式处理，C 声明位于 `native/include/content_codec.h`。按职责组织，不为同包调用增加独立 ABI 版本协商。
- `Cargo.lock` 记录依赖解析；库依赖使用常规版本范围。工具链配置由 `native/rust-toolchain.toml` 提供，构建 hook 和 CI 使用同一来源。

## Output Guidelines

- 直接说明变更结果、验证范围及剩余事项，省略重复背景和无助于决策的内容。
- 区分源码审查、单元测试、真实链路、构建、设备安装和人工确认；只报告证据实际覆盖的结果。
- 遇到需要用户决定的行为或缺少必要信息时使用提问工具，继续推进不依赖答案的工作。

## Unexpected Situations

记录会影响后续开发的实际约束；已修复或过时的条目及时清理，不堆积临时网络和探针记录。

- 生命周期初始化依赖 `initDependencies`，列表中的文字位置不是执行顺序；遗漏 bean 或依赖会影响启动。
- 设置的默认值可能依赖平台及初始化阶段。配置迁移先核对来源版本与平台默认值，不能仅凭字段存在判断用户设置过。
- 本地副本路径由 owner 与任务引用确定。修改默认下载目录不应重新推导既有副本的位置。
- 日志输出存在异步初始化；不验证日志的存储测试使用已有同步测试日志夹具，避免临时目录清理与文件日志竞争。
- 四平台构建由 `.github/workflows/build_publish.yml` 输出 workflow artifacts；Windows 的 Native Assets 使用统一目录安装规则。
