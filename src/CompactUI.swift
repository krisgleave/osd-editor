// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
final class CompactSection:NSBox{
 let header=NSButton();let body:NSView;let stack=NSStackView();var expanded:Bool
 init(_ title:String,_ content:NSView,_ collapsed:Bool){
  body=content;expanded = !collapsed;super.init(frame:.zero)
  boxType = .primary;borderType = .lineBorder;titlePosition = .noTitle;contentViewMargins=NSSize(width:12,height:10)
  header.title=title;header.font = .boldSystemFont(ofSize:13);header.isBordered=false;header.alignment = .left;header.imagePosition = .imageLeading;header.target=self;header.action=nil;header.setAccessibilityLabel(title)
  stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8;stack.detachesHiddenViews=true
  stack.translatesAutoresizingMaskIntoConstraints=false;let host=NSView();contentView=host;host.addSubview(stack)
  stack.addArrangedSubview(header);stack.addArrangedSubview(content)
  NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:host.leadingAnchor),stack.trailingAnchor.constraint(equalTo:host.trailingAnchor),stack.topAnchor.constraint(equalTo:host.topAnchor),stack.bottomAnchor.constraint(equalTo:host.bottomAnchor),header.widthAnchor.constraint(equalTo:stack.widthAnchor),header.heightAnchor.constraint(equalToConstant:22)])
  update()
 }
 required init?(coder:NSCoder){fatalError("init(coder:) unavailable")}
 @objc func toggle(){expanded.toggle();update()}
 override var intrinsicContentSize:NSSize{let size=stack.fittingSize;return NSSize(width:size.width+24,height:size.height+20)}
 func update(){body.isHidden = !expanded;header.image=nil;header.toolTip=nil;invalidateIntrinsicContentSize();needsLayout=true}
}
func configureIcon(_ button:NSButton,_ symbol:String,_ label:String){
 button.title="";button.image=NSImage(systemSymbolName:symbol,accessibilityDescription:label);button.imagePosition = .imageOnly;button.bezelStyle = .rounded;button.toolTip=label;button.setAccessibilityLabel(label)
 button.widthAnchor.constraint(equalToConstant:30).isActive=true;button.heightAnchor.constraint(equalToConstant:30).isActive=true
}
let extraTextChoices:[(String,String)]=[
 ("Menlo","Menlo-Bold"),("DIN Alternate","DINAlternate-Bold"),("Avenir Next","AvenirNext-DemiBold"),
 ("Helvetica Neue","HelveticaNeue-Medium"),("Verdana","Verdana-Bold")
]

func toolPanel(_ content:NSView,verticalPadding:CGFloat=8)->NSBox{let box=NSBox();box.boxType = .custom;box.titlePosition = .noTitle;box.borderWidth=1;box.cornerRadius=8;box.borderColor = .separatorColor;box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45);box.contentViewMargins=NSSize(width:10,height:verticalPadding);let host=NSView();box.contentView=host;content.translatesAutoresizingMaskIntoConstraints=false;host.addSubview(content);NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo:host.leadingAnchor),content.trailingAnchor.constraint(equalTo:host.trailingAnchor),content.topAnchor.constraint(equalTo:host.topAnchor),content.bottomAnchor.constraint(equalTo:host.bottomAnchor)]);box.heightAnchor.constraint(greaterThanOrEqualTo:content.heightAnchor,constant:verticalPadding*2).isActive=true;return box}

func trimMarkIcon(_ markIn:Bool)->NSImage{
 let image=NSImage(size:NSSize(width:20,height:20),flipped:false){_ in
  NSColor.labelColor.setStroke();let bracket=NSBezierPath();bracket.lineWidth=1.8
  let x:CGFloat=markIn ? 6:14;let direction:CGFloat=markIn ? 1:-1
  bracket.move(to:NSPoint(x:x+direction*5,y:17));bracket.line(to:NSPoint(x:x,y:17));bracket.line(to:NSPoint(x:x,y:3));bracket.line(to:NSPoint(x:x+direction*5,y:3));bracket.stroke()
  NSColor.labelColor.setFill();let arrow=NSBezierPath();arrow.move(to:NSPoint(x:x+direction*2,y:10));arrow.line(to:NSPoint(x:x+direction*8,y:14));arrow.line(to:NSPoint(x:x+direction*8,y:6));arrow.close();arrow.fill();return true
 };image.isTemplate=true;return image
}

func colouredSymbol(_ name:String,_ colour:NSColor)->NSImage?{
 guard let symbol=NSImage(systemSymbolName:name,accessibilityDescription:"Show hidden selection") else{return nil}
 let result=NSImage(size:NSSize(width:20,height:20),flipped:false){rect in
  symbol.draw(in:rect);NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current?.compositingOperation = .sourceIn;colour.setFill();NSBezierPath(rect:rect).fill();NSGraphicsContext.restoreGraphicsState();return true
 };result.isTemplate=false;return result
}

func visibilityIcon(hidden:Bool)->NSImage?{
 guard let eye=NSImage(systemSymbolName:"eye",accessibilityDescription:hidden ? "Hidden":"Visible") else{return nil}
 let image=NSImage(size:NSSize(width:20,height:20),flipped:false){rect in
  let aspect=eye.size.height/eye.size.width;let width:CGFloat=18;let height=width*aspect
  eye.draw(in:NSRect(x:1,y:(20-height)/2,width:width,height:height))
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current?.compositingOperation = .sourceIn;(hidden ? NSColor.systemRed:NSColor.labelColor).setFill();NSBezierPath(rect:rect).fill();NSGraphicsContext.restoreGraphicsState()
  if hidden{NSColor.systemRed.setStroke();let slash=NSBezierPath();slash.lineWidth=1.8;slash.lineCapStyle = .round;slash.move(to:NSPoint(x:3,y:17));slash.line(to:NSPoint(x:17,y:3));slash.stroke()};return true
 };image.isTemplate=false;return image
}
