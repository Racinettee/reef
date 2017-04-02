# reef
Lua 5.1 binding in the D language

### About
Reef is a Lua binding in D designed to expose classes using user defined attributes.

### Usage
In D land
```@LuaExport("MyClass")
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
state.registerClass!MyClass;```
And in Lua
```assert(MyClass.new('bill'):getName() == 'bill')```