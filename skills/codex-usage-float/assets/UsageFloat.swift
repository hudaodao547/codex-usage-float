import Cocoa

struct Quota {
 let used: Double
 let reset: Date?
 let minutes: Int?
 var remaining: Double { max(0, min(100, 100-used)) }
 init?(_ value: Any?) {
  guard let d = value as? [String:Any], let used = d["usedPercent"] as? Double else { return nil }
  self.used = used
  reset = (d["resetsAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
  minutes = d["windowDurationMins"] as? Int
 }
}

final class UsageClient {
 var process: Process?
 var input: Pipe?
 var output: Pipe?
 var buffer = Data()
 var callback: (([String:Any]?, String?) -> Void)?
 var nextID = 10
 var waiting: Int?
 var ready = false
 var timeout: DispatchWorkItem?
 func start() {
  stop()
  let p=Process(), i=Pipe(), o=Pipe()
  guard let cli=Self.findCodex() else {
   callback?(nil,"找不到 Codex · 请安装桌面版或命令行工具");return
  }
  p.executableURL=cli
  p.arguments=["app-server","--stdio"]
  p.standardInput=i; p.standardOutput=o; p.standardError=FileHandle.nullDevice
  p.currentDirectoryURL=URL(fileURLWithPath:NSTemporaryDirectory())
  process=p; input=i; output=o; buffer=Data(); ready=false
  o.fileHandleForReading.readabilityHandler = { [weak self, weak p] h in
   let data=h.availableData
   guard !data.isEmpty else { h.readabilityHandler=nil; return }
   DispatchQueue.main.async {
    guard let self=self, self.process === p else { return }
    self.buffer.append(data)
    if self.buffer.count > 8*1024*1024 {
     self.stop();self.callback?(nil,"连接返回异常 · 一分钟后重试");return
    }
    while let end=self.buffer.firstIndex(of:10) {
     let line=self.buffer.prefix(upTo:end); self.buffer.removeSubrange(...end)
     if let v=(try? JSONSerialization.jsonObject(with:line)) as? [String:Any] { self.receive(v) }
    }
   }
  }
  p.terminationHandler = { [weak self, weak p] _ in DispatchQueue.main.async {
   guard let self=self, self.process === p else { return }
   self.ready=false; self.timeout?.cancel(); self.waiting=nil
   self.callback?(nil,"连接已断开 · 一分钟后重试")
  }}
  do {
   try p.run()
   send(["id":1,"method":"initialize","params":["clientInfo":["name":"codex_usage_float","version":"1.0.0"]]])
   deadline()
  } catch { callback?(nil,"无法启动 Codex · 请确认桌面版已安装") }
 }
 func send(_ v:[String:Any]) {
  guard let data=try? JSONSerialization.data(withJSONObject:v) else{return}
  do { try input?.fileHandleForWriting.write(contentsOf:data+Data([10])) }
  catch { callback?(nil,"连接失败 · 请重试") }
 }
 func receive(_ v:[String:Any]) {
  guard let id=v["id"] as? Int else{return}
  if id == 1 {
   timeout?.cancel()
   guard v["error"] == nil else { callback?(nil,"Codex 初始化失败"); return }
   ready=true; send(["method":"initialized"]); refresh()
  } else if id == waiting {
   timeout?.cancel(); waiting=nil
   if let result=v["result"] as? [String:Any] { callback?(result,nil) }
   else { callback?(nil,"读取失败 · 请在 Codex 确认登录状态") }
  }
 }
 func deadline() {
  timeout?.cancel()
  let item=DispatchWorkItem { [weak self] in
   self?.stop(); self?.callback?(nil,"连接超时 · 一分钟后重试")
  }; timeout=item
  DispatchQueue.main.asyncAfter(deadline:.now()+45,execute:item)
 }
 func refresh() {
  guard process?.isRunning == true, ready else { start(); return }
  guard waiting == nil else{return}
  nextID+=1; waiting=nextID
  send(["id":nextID,"method":"account/rateLimits/read","params":["excludeResetCreditDetails":true]])
  deadline()
 }
 func stop() {
  timeout?.cancel(); timeout=nil; waiting=nil; ready=false
  let p=process; process=nil
  p?.terminationHandler=nil
  if p?.isRunning == true { p?.terminate() }
  output?.fileHandleForReading.readabilityHandler=nil
  try? input?.fileHandleForWriting.close()
  try? output?.fileHandleForReading.close()
  input=nil;output=nil
 }
 static func findCodex()->URL? {
  let home=FileManager.default.homeDirectoryForCurrentUser.path
  let bundles=["/Applications/ChatGPT.app","/Applications/Codex.app",home+"/Applications/ChatGPT.app",home+"/Applications/Codex.app"]
  var candidates=bundles.map{$0+"/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"}
  candidates += bundles.map{$0+"/Contents/Resources/codex"}
  candidates += [home+"/.local/bin/codex","/opt/homebrew/bin/codex","/usr/local/bin/codex"]
  candidates += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator:":").map{String($0)+"/codex"}
  return candidates.first{FileManager.default.isExecutableFile(atPath:$0)}.map{URL(fileURLWithPath:$0)}
 }
 deinit { stop() }
}

final class Panel: NSPanel {
 override var canBecomeKey: Bool { true }
 override var canBecomeMain: Bool { false }
}
final class WhiteBar: NSView {
 var doubleValue:Double=0 {didSet{needsDisplay=true}}
 override func draw(_ dirtyRect:NSRect) {
  NSColor.white.withAlphaComponent(0.16).setFill()
  NSBezierPath(roundedRect:bounds,xRadius:2.5,yRadius:2.5).fill()
  let fill=NSRect(x:0,y:0,width:bounds.width*max(0,min(100,doubleValue))/100,height:bounds.height)
  NSColor.white.withAlphaComponent(0.88).setFill()
  NSBezierPath(roundedRect:fill,xRadius:2.5,yRadius:2.5).fill()
 }
}
final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
 let client=UsageClient()
 var panel: Panel!
 var glass: NSVisualEffectView!
 var values:[NSTextField]=[]
 var resets:[NSTextField]=[]
 var bars:[WhiteBar]=[]
 var lockButton:NSButton!
 var positionLocked=false
 var status=NSTextField(labelWithString:"正在连接…")
 var quotas:[Quota?]=[nil,nil]
 var updated: Date?
 var error: String?
 var timer: Timer?
 var ticker: Timer?
 var pinned=false
 func label(_ text:String,_ size:CGFloat,_ weight:NSFont.Weight = .regular)->NSTextField {
  let l=NSTextField(labelWithString:text);l.font = .systemFont(ofSize:size,weight:weight);l.lineBreakMode = .byTruncatingTail;l.textColor = .white;return l
 }
 func applicationDidFinishLaunching(_ n:Notification) {
  NSApp.setActivationPolicy(.accessory)
  panel=Panel(contentRect:NSRect(x:0,y:0,width:338,height:158),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  panel.title="Codex 用量";panel.isFloatingPanel=false;applyDisplayMode()
  panel.hidesOnDeactivate=false;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=true
  applyDisplayMode()
  panel.isMovableByWindowBackground=true;panel.isReleasedWhenClosed=false
  panel.setFrameAutosaveName("CodexUsageFloatGlass")
  panel.delegate=self
  let restored=panel.setFrameUsingName("CodexUsageFloatGlass")
  if !restored,let screen=NSScreen.main {
   panel.setFrameTopLeftPoint(NSPoint(x:screen.visibleFrame.maxX-362,y:screen.visibleFrame.maxY-100))
  }
  if !NSScreen.screens.contains(where:{$0.visibleFrame.intersects(panel.frame)}),let screen=NSScreen.main {
   panel.setFrameTopLeftPoint(NSPoint(x:screen.visibleFrame.maxX-362,y:screen.visibleFrame.maxY-100))
  }
  let root=NSView(frame:NSRect(x:0,y:0,width:338,height:158));root.wantsLayer=true
  root.layer?.cornerRadius=22;root.layer?.masksToBounds=true
  panel.contentView=root
  glass=NSVisualEffectView(frame:root.bounds);glass.material = .hudWindow
  glass.blendingMode = .behindWindow;glass.state = .active;glass.appearance=NSAppearance(named:.darkAqua)
  if !UserDefaults.standard.bool(forKey:"whiteGlassTheme") {
   UserDefaults.standard.set(0.22,forKey:"glassOpacity");UserDefaults.standard.set(true,forKey:"whiteGlassTheme")
  }
  let saved=UserDefaults.standard.double(forKey:"glassOpacity")
  glass.alphaValue=saved>0 ? saved : 0.22;root.addSubview(glass)
  root.layer?.borderColor=NSColor.white.withAlphaComponent(0.28).cgColor;root.layer?.borderWidth=0.7
  let title=label("Codex",12,.semibold);title.frame=NSRect(x:18,y:126,width:120,height:18);root.addSubview(title)
  let more=NSButton(title:"···",target:self,action:#selector(showMenu(_:)))
  more.contentTintColor = .white;more.isBordered=false;more.font = .systemFont(ofSize:19,weight:.medium)
  more.frame=NSRect(x:290,y:123,width:30,height:24);more.toolTip="锁定位置、刷新、透明度与退出";root.addSubview(more)
  lockButton=NSButton(image:NSImage(systemSymbolName:"lock.open",accessibilityDescription:"锁定位置")!,target:self,action:#selector(togglePositionLock))
  lockButton.isBordered=false;lockButton.contentTintColor = .white
  lockButton.frame=NSRect(x:263,y:124,width:25,height:23);root.addSubview(lockButton)
  positionLocked=UserDefaults.standard.bool(forKey:"positionLocked");applyPositionLock()
  let separator=NSView(frame:NSRect(x:168.5,y:37,width:0.5,height:72));separator.wantsLayer=true;separator.layer?.backgroundColor=NSColor.white.withAlphaComponent(0.18).cgColor;root.addSubview(separator)
  for (idx,title) in ["5 小时 · 剩余","每周 · 剩余"].enumerated() {
   let x=CGFloat(idx==0 ? 18 : 187)
   let name=label(title,11,.medium);name.textColor = .white.withAlphaComponent(0.72);name.frame=NSRect(x:x,y:102,width:134,height:16);root.addSubview(name)
   let value=label("—",30,.semibold);value.font = .monospacedDigitSystemFont(ofSize:30,weight:.semibold);value.frame=NSRect(x:x-1,y:66,width:136,height:38);root.addSubview(value);values.append(value)
   let bar=WhiteBar(frame:NSRect(x:x,y:56,width:133,height:5));root.addSubview(bar);bars.append(bar)
   let reset=label("等待读取",10);reset.textColor = .white.withAlphaComponent(0.72);reset.frame=NSRect(x:x,y:34,width:135,height:17);root.addSubview(reset);resets.append(reset)
  }
  status.font = .systemFont(ofSize:9);status.textColor = .white.withAlphaComponent(0.6);status.frame=NSRect(x:18,y:12,width:302,height:15);status.isHidden=true;root.addSubview(status)
  let context=makeMenu();root.menu=context
  client.callback = { [weak self] r,e in self?.received(r,e) }
  panel.orderFrontRegardless();client.start()
  timer=Timer.scheduledTimer(withTimeInterval:60,repeats:true){[weak self] _ in self?.client.refresh()}
  ticker=Timer.scheduledTimer(withTimeInterval:10,repeats:true){[weak self] _ in self?.render()}
 }
 func makeMenu()->NSMenu {
  let menu=NSMenu()
  for (title,selector) in [(positionLocked ? "解锁位置（允许拖动）" : "锁定当前位置",#selector(togglePositionLock)),("立即刷新",#selector(refresh)),(pinned ? "切换为桌面小组件（不遮挡应用）" : "切换为始终置顶（覆盖应用）",#selector(togglePin))] {
   let item=NSMenuItem(title:title,action:selector,keyEquivalent:"");item.target=self;menu.addItem(item)
  }
  let opacity=NSMenuItem(title:"透明程度",action:nil,keyEquivalent:"")
  let sub=NSMenu()
  for (title,tag) in [("更透明",12),("适中",22),("更清晰",40)] {
   let item=NSMenuItem(title:title,action:#selector(setOpacity(_:)),keyEquivalent:"");item.target=self;item.tag=tag
   item.state=abs(glass.alphaValue-Double(tag)/100)<0.01 ? .on : .off;sub.addItem(item)
  };opacity.submenu=sub;menu.addItem(opacity);menu.addItem(.separator())
  let quit=NSMenuItem(title:"退出悬浮窗",action:#selector(quit),keyEquivalent:"");quit.target=self;menu.addItem(quit);return menu
 }
 @objc func showMenu(_ sender:NSButton) {let menu=makeMenu();menu.popUp(positioning:nil,at:NSPoint(x:0,y:0),in:sender)}
 func savePosition(){panel.saveFrame(usingName:"CodexUsageFloatGlass");UserDefaults.standard.set(true,forKey:"glassPositionSaved")}
 func windowDidMove(_ notification:Notification){savePosition()}
 func applyPositionLock(){
  panel.isMovable = !positionLocked;panel.isMovableByWindowBackground = !positionLocked
  lockButton?.image=NSImage(systemSymbolName:positionLocked ? "lock.fill" : "lock.open",accessibilityDescription:positionLocked ? "解锁位置" : "锁定位置")
  lockButton?.toolTip=positionLocked ? "位置已锁定 · 点击解锁" : "点击锁定当前位置"
 }
 @objc func togglePositionLock(){
  positionLocked.toggle();UserDefaults.standard.set(positionLocked,forKey:"positionLocked")
  savePosition();applyPositionLock();panel.contentView?.menu=makeMenu()
 }
 @objc func refresh(){status.stringValue="正在刷新…";client.refresh()}
 func applyDisplayMode(){
  pinned=UserDefaults.standard.bool(forKey:"alwaysOnTop")
  panel.isFloatingPanel=pinned
  panel.level=pinned ? .floating : NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.desktopIconWindow))+1)
  panel.collectionBehavior=pinned ? [.canJoinAllSpaces,.fullScreenAuxiliary] : [.canJoinAllSpaces,.stationary,.ignoresCycle,.fullScreenNone]
 }
 @objc func togglePin(){
  UserDefaults.standard.set(!pinned,forKey:"alwaysOnTop");applyDisplayMode();panel.contentView?.menu=makeMenu()
 }
 @objc func setOpacity(_ sender:NSMenuItem){glass.alphaValue=Double(sender.tag)/100;UserDefaults.standard.set(glass.alphaValue,forKey:"glassOpacity");panel.contentView?.menu=makeMenu()}
 func received(_ result:[String:Any]?,_ e:String?) {
  error=e
  if let r=result {
   let map=r["rateLimitsByLimitId"] as? [String:Any]
   let bucket:[String:Any]?
   if let map=map,!map.isEmpty {bucket=map["codex"] as? [String:Any]}else{bucket=r["rateLimits"] as? [String:Any]}
   if let b=bucket {
    let all=[Quota(b["primary"]),Quota(b["secondary"])].compactMap{$0}
    quotas=[all.first{$0.minutes==300},all.first{$0.minutes==10080}];updated=Date()
    if quotas.allSatisfy({$0 == nil}){error="此账户暂未提供这两种额度"}
   }else{quotas=[nil,nil];error="此账户未提供 Codex 额度"}
  };render()
 }
 func render() {
  for idx in 0..<2 {
   guard let q=quotas[idx] else{values[idx].stringValue="—";resets[idx].stringValue="暂未取得数据";bars[idx].doubleValue=0;continue}
   values[idx].stringValue="\(Int(q.remaining))%"
   values[idx].textColor=q.remaining<=10 ? .systemRed : (q.remaining<=25 ? .systemOrange : .white)
   bars[idx].doubleValue=q.remaining
   if let d=q.reset {
    let seconds=d.timeIntervalSinceNow
    if seconds<=0{resets[idx].stringValue="等待重置更新"}
    else{
     let minutes=Int(ceil(seconds/60)),days=minutes/1440,hours=(minutes%1440)/60,mins=minutes%60
     resets[idx].stringValue=days>0 ? "\(days)天\(hours)小时后重置" : "\(hours)小时\(mins)分后重置"
    }
    let f=DateFormatter();f.locale=Locale(identifier:"zh_CN");f.dateFormat="M月d日 HH:mm"
    resets[idx].toolTip="重置时间：\(f.string(from:d))"
   }else{resets[idx].stringValue="重置时间暂不可用"}
  }
  status.isHidden = error == nil
  if let e=error{status.stringValue=e+(updated == nil ? "" : " · 上次数据");status.textColor = .systemOrange}
  else if let date=updated {
   let age=Int(Date().timeIntervalSince(date));let low=quotas.compactMap{$0}.contains{$0.remaining<=25}
   status.stringValue=low ? "额度偏低，请留意用量" : "\(age<60 ? "刚刚" : "\(age/60)分钟前")更新 · 每分钟自动读取"
   status.textColor=low ? .systemOrange : .white.withAlphaComponent(0.72)
  }
 }
 @objc func quit(){savePosition();NSApp.terminate(nil)}
 func applicationWillTerminate(_ n:Notification){savePosition();client.stop()}
}
let app=NSApplication.shared
let delegate=App();app.delegate=delegate;app.run()
