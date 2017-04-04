# reef
Lua 5.1 binding in the D language

### About
Reef is a Lua binding in D designed to expose classes using user defined attributes.

### Usage
In D land
```D
@LuaExport("MyClass")
class MyClass
{
  @LuaExport("", MethodType.ctor)
  public this(string name)
  {
    myname = name;
  }
  private string myname;

  @LuaExport("getName", MethodType.method, "", RetType.str)
  public string getName()
  {
    return myname;
  }
}
// ...
State state = new State();
state.openLibs();
state.registerClass!MyClass;
```

And in Lua

```Lua
assert(MyClass.new('bill'):getName() == 'bill')
```

### Example continued
Say you're using LGI and GtkD in conjunction and you'd like to expose an instance of your widget to LGI. LGI expects widgets from
C to be passed as lightuserdata.

In D:
```D
@LuaExport("AppWindow")
class AppWindow : MainWindow
{
  @LuaExport("", MethodType.ctor)
  public this()
  {
    super("Example App Window");
    setSizeRequest(600, 400);

    builder = new Builder();
    if(!builder.addFromFile("interface/mainmenu.glade"))
			writeln("Could not load gladefile");

    mainMenu = cast(T)builder.getObject("mainMenu");
    // ...
    // Hook events to the menu items
    // ...
    showAll;
  }
  @LuaExport("menubar", MethodType.none, "getMenuBarStruct()", RetType.none, MemberType.lightud)
  MenuBar mainMenu;
}
// ....
state.registerClass!AppWindow;
```

In Lua:

```Lua
local mainWindow = AppWindow.new()

local menuBar = Gtk.MenuBar(mainWindow.menubar)
menuBar:append(Gtk.MenuItem {
  label = 'Hello'
})
menuBar:show_all()
```