# Reef
Lua 5.1 binding in the D language

### About
Reef is a Lua binding in D designed to expose classes using user defined attributes.

### Usage
```@LuaExport("MyClass")
class MyClass
{
    @LuaExport("", MethodType.ctor)
    public this(string name)
    {
        myname = name;
    }
}