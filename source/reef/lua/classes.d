module reef.lua.classes;

import core.memory;
import std.stdio;
import std.string;
import std.traits;

import luad.c.all;
import reef.lua.state;
import reef.lua.attrib;
import reef.lua.stack;

template hasCtor(T)
{
    enum hasCtor = __traits(compiles, __traits(getOverloads, T.init, "__ctor"));
}

void fillArgs(Del, int index, bool forMethod=true)(lua_State* L, ref Parameters!Del params)
{
  alias ParamList = Parameters!Del;
  const int luaStartingArgIndex = 1; // index 1 is the self, index 2 is our first arugment that we want to deal with
  //static if(forMethod)
  int luaOffsetArg = index+luaStartingArgIndex+(forMethod ? 1 : 0);
  //else
  //  const int luaOffsetArg = index+luaStartingArgIndex;
  static if(is(typeof(params[index]) == int))
  {
    pragma(msg, "Generating int parameter");
    params[index] = luaL_checkint(L, luaOffsetArg);
  }
  else static if(is(typeof(params[index]) == string))
  {
    pragma(msg, "Generating string parameter");
    params[index] = cast(string)fromStringz(luaL_checkstring(L, luaOffsetArg));
  }
  else static if(is(typeof(params[index]) == float) || is(typeof(params[index]) == double))
  {
    pragma(msg, "Generating float parameter");
    params[index] = luaL_checknumber(L, luaOffsetArg);
  }
  else static if(is(typeof(params[index]) == bool))
  {
    pragma(msg, "Generating bool parameter");
    params[index] = cast(bool)luaL_checkboolean(L, luaOffsetArg);
  }
  static if(index+1 < ParamList.length)
    fillArgs!(Del, index+1, forMethod)(L, params);
}

extern(C) int methodWrapper(Del, Class, uint index)(lua_State* L)
{
  alias ParameterTypeTuple!Del Args;

  static assert ((variadicFunctionStyle!Del != Variadic.d && variadicFunctionStyle!Del != Variadic.c),
		"Non-typesafe variadic functions are not supported.");

  int top = lua_gettop(L);

  static if (variadicFunctionStyle!Del == Variadic.typesafe)
		enum requiredArgs = Args.length;
	else
		enum requiredArgs = Args.length + 1;

  if(top < requiredArgs)
  {
    writeln("Argument error in D method wrapper");
    return 0;
  }
  
  Class self = *cast(Class*)lua_touserdata(L, 1);
  
  Del func;
  func.ptr = cast(void*)self;
  func.funcptr = cast(typeof(func.funcptr))lua_touserdata(L, lua_upvalueindex(1));

  Parameters!Del typeObj;
  pragma(msg, Parameters!Del);
  fillArgs!(Del, 0, true)(L, typeObj);

  static if(hasUDA!(mixin("Class."~__traits(derivedMembers, Class)[index]), LuaExport))
  {
    alias RT = ReturnType!Del;
    static if(!is(RT == void))
    {
      RT returnValue = func(typeObj);
      enum luaUda = getUDAs!(mixin("Class."~__traits(derivedMembers, Class)[index]), LuaExport)[0];
      static if(luaUda.rtype == RetType.lightud)
      {
        static if(luaUda.submember != "")
        {
          lua_pushlightuserdata(L, mixin("returnValue."~luaUda.submember));
          return 1;
        }
      }
      else
      {
        pushValue(L, returnValue);
        return 1;
      }
    }
    else
    {
      func(typeObj);
      return 0;
    }
  }
  
  assert(0, "Somehow reached a spot in methodWrapper that shouldn't be possible");
}

private T extrapolateThis(T, uint index)(lua_State* L, uint argc)
{
  static assert(hasUDA!(T, LuaExport));
  //enum thisOverloads = [ __traits(getOverloads, T, "__ctor") ];
  //alias thisSymbol = thisOverloads[index];
  //pragma(msg, __traits(getOverloads, T, "__ctor"));
  pragma(msg, Parameters!(typeof(__traits(getOverloads, T, "__ctor")[index])).stringof);
  static if(
    __traits(getProtection, __traits(getOverloads, T, "__ctor")[index]) == "public" &&
    hasUDA!(__traits(getOverloads, T, "__ctor")[index], LuaExport))
  {
    enum luaUda = getUDAs!(__traits(getOverloads, T, "__ctor")[index], LuaExport)[0];
    static if(luaUda.type == MethodType.ctor)
    {
      Parameters!(__traits(getOverloads, T, "__ctor")[index]) args;
      if(argc == args.length) {
        fillArgs!(typeof(__traits(getOverloads, T, "__ctor")[index]), 0, false)(L, args);
        return new T(args);
      }
    }
  }
  static if(index+1 < __traits(getOverloads, T, "__ctor").length)
    return extrapolateThis!(T, index+1)(L, argc);
  assert(false, "We shouldn't end up here");
}

/// Method used for instantiating userdata
extern(C) int newUserdata(T)(lua_State* L)
{
  int nargs = lua_gettop(L);
  alias thisOverloads = typeof(__traits(getOverloads, T, "__ctor"));
  //pragma(msg, thisOverloads);

  pushInstance!T(L, extrapolateThis!(T, 0)(L, nargs)); //new T());
  return 1;
}
/// Method for garbage collecting userdata
extern(C) int gcUserdata(lua_State* L)
{
  GC.removeRoot(lua_touserdata(L, 1));
  return 0;
};

void registerClass(T)(State state)
{
  static assert(hasUDA!(T, LuaExport));

  lua_CFunction x_gc = (lua_State* L)
  {
    GC.removeRoot(lua_touserdata(L, 1));
    return 0;
  };

  lua_State* L = state.state;

  // -------------------------------------------------------------------
  // the top of the stack being the right-most in the following comments
  // -----------------------------------------------------
  // Create a metatable named after the D-class and add some constructors and methods
  // ---------------------------------------------------------------------------------
  luaL_newmetatable(L, T.stringof); // x = {}
  lua_pushvalue(L, -1); // x = {}, x = {} 
  lua_setfield(L, -1, "__index"); // x = {__index = x}
  lua_pushcfunction(L, &newUserdata!(T)); // x = {__index = x}, x_new
  lua_setfield(L, -2, "new"); // x = {__index = x, new = x_new}
  lua_pushcfunction(L, x_gc); // x = {__index = x, new = x_new}, x_gc
  lua_setfield(L, -2, "__gc"); // x = {__index = x, new = x_new, __gc = x_gc}

  // ---------------------------------
  pushMethods!(T, 0)(L);
  lua_setglobal(L, T.stringof);
}

void pushMethods(T, uint index)(lua_State* L)
{
  static assert(hasUDA!(T, LuaExport));
  debug {
    pragma(msg, __traits(derivedMembers, T)[index]);
  }
  static if(__traits(derivedMembers, T)[index] != "this" &&
    __traits(getProtection, mixin("T."~__traits(derivedMembers, T)[index])) == "public" &&
    hasUDA!(mixin("T."~__traits(derivedMembers, T)[index]), LuaExport)) 
  {
    // Get the lua uda struct associated with this member function
    enum luaUda = getUDAs!(mixin("T."~__traits(derivedMembers, T)[index]), LuaExport)[0];
    static if(luaUda.type == MethodType.method)
    {
      alias DelType = typeof(mixin("&T.init."~__traits(derivedMembers, T)[index]));
      lua_pushlightuserdata(L, &mixin("T."~__traits(derivedMembers,T)[index])); // x = { ... }, &T.member
      lua_pushcclosure(L, &methodWrapper!(DelType, T, index), 1); // x = { ... }, closure { &T.member }
      lua_setfield(L, -2, toStringz(luaUda.name)); // x = { ..., fn = closure { &T.member } }
    }
  }
  static if(index+1 < __traits(derivedMembers, T).length)
    pushMethods!(T, index+1)(L);
}

// T refers to a de-referenced instance
void pushLightUds(T, uint index)(lua_State* L, T instance)
{
  static assert(hasUDA!(T, LuaExport));
  // This first case handles empty classes
  debug {
    pragma(msg, __traits(derivedMembers, T)[index]);
  }
  static if(__traits(derivedMembers, T).length > 1 &&
    __traits(derivedMembers, T)[index] != "this" &&
    __traits(getProtection, mixin("T."~__traits(derivedMembers, T)[index])) == "public" &&
    hasUDA!(mixin("T."~__traits(derivedMembers, T)[index]), LuaExport))
  {
    // Get the lua uda struct associated with this member function
    enum luaUda = getUDAs!(mixin("T."~__traits(derivedMembers, T)[index]), LuaExport)[0];
    static if(luaUda.memtype == MemberType.lightud)
    {
      static if(luaUda.submember != "")
      {
        auto lightuserdata = mixin("instance."~__traits(derivedMembers, T)[index]~"."~luaUda.submember);
        if(lightuserdata is null)
          writeln("Error: provided light userdata "~luaUda.name~" is null");
        lua_pushlightuserdata(L, lightuserdata);
      }
      else
        lua_pushlightuserdata(L, &mixin("instance."~__traits(derivedMembers, T)[index]));
      lua_setfield(L, -2, toStringz(luaUda.name));
    }
  }
  static if(index+1 < __traits(derivedMembers, T).length)
    pushLightUds!(T, index+1)(L, instance);
}
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
unittest
{
  import reef.lua.state;
  State state = new State();
  state.openLibs();
  state.registerClass!MyClass;
  state.getGlobal("MyClass");
  lua_State* L = state.state;
  assert(cast(bool)lua_isnil(L, -1) == false);
  assert(lua_type(L, -1) == LUA_TTABLE);
  state.push("jean");
  lua_getfield(L, -2, "new");
  assert(lua_type(L, -1) == LUA_TFUNCTION);
  //assert(lua_pcall(L, 1, 1, 0) == 0);
  if(lua_pcall(L, 1, 1, 0) != 0) {
    //lua_error(L);
    writeln(fromStringz(lua_tostring(L, -1)));
    assert(false);
  }
  assert(lua_type(L, -1) == LUA_TUSERDATA);
  lua_getfield(L, -1, "getName");
  assert(cast(bool)lua_isnil(L, -1) == false);
  assert(lua_pcall(L, 1, 1, 0) == 0);
  assert(luaL_checkstring(L, -1) == "jean");

  lua_pop(L, 2);
  state.doString("assert(MyClass.new('bill'):getName() == 'bill')");
  //assert(fromStringz(luaL_checkstring(L, -1)) == "bill");
}