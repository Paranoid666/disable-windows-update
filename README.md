# Windows Update Disable / Restore

用于在 Windows 11 (25H2) 上**永久关闭**系统自动更新,并支持一键**恢复**到系统默认状态。

## 工作原理

关闭脚本会执行以下操作:

- 写入组策略注册表:`NoAutoUpdate=1`、`DoNotConnectToWindowsUpdateInternetLocations=1`
- 停用更新相关服务:`wuauserv`、`UsoSvc`、`WaaSMedicSvc`
- 禁用触发更新的计划任务(UpdateOrchestrator / WindowsUpdate / WaaSMedic / UUS)

恢复脚本会撤销以上所有改动,把服务恢复到默认启动类型。

## 使用方式

双击运行 (会自动请求管理员权限,UAC 弹窗点「是」):

- `Disable-WindowsUpdate.bat` — 永久关闭更新
- `Enable-WindowsUpdate.bat` — 恢复系统默认

## 备份位置

原始服务启动类型与组策略注册表会备份到:

```
C:\ProgramData\WindowsUpdate_Backup\
```

> ⚠️ 关闭更新后系统将不再接收安全补丁与驱动更新,长期使用存在安全风险。
> 需要更新时请先运行 `Enable-WindowsUpdate.bat` 恢复。
