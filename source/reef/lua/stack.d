module reef.lua.stack;

import core.memory;

import luad.c.all;

import reef.lua.classes : pushInstance;
import reef.lua.exception;
import reef.lua.state;

import std.stdio;
import std.string;
import std.traits;

package void pushValue(T)(lua_State* L, T value) if(!is(T == struct))
{
  static if(is(T == typeof(null)))
    lua_pushnil(L);
  else static if(is(T == bool))
    lua_pushboolean(L, value);
  else static if(is(T == char))
    lua_pushlstring(L, &value, 1);
  else static if(is(T : lua_Integer))
    lua_pushinteger(L, value);
  else static if(is(T : lua_Number))
    lua_pushnumber(L, value);
  else static if(is(T : const(char)[]))
    lua_pushlstring(L, value.ptr, value.length);
  else static if(is(T : const(char)*))
    lua_pushstring(L, value);
  else static if(is(T == lua_CFunction) && functionLinkage!T == "C")
    lua_pushcfunction(L, value);
  else static if(is(T == class))
  {
    if(value is null)
      lua_pushnil(L);
    else
			pushInstance(L, value);
  }
  else
    static assert(false, "Unsupported type being pushed: "~T.stringof~" in stack.d");
}

unittest
{
  import reef.lua.attrib : LuaExport;
  import reef.lua.state : State;
  auto state = new State();
  lua_State* L = state.state;
  // Tests push typeof(null)
  pushValue(L, null);
  assert(cast(bool)lua_isnil(L, -1));
  // Tests value is null
  @LuaExport("ExampleClass")
  class ExampleClass { }
  ExampleClass nullExample;
  pushValue(L, nullExample);
  assert(cast(bool)lua_isnil(L, -1));
  pushValue(L, true);
  assert(lua_type(L, -1) == LUA_TBOOLEAN);
  pushValue(L, 1);
  assert(lua_type(L, -1) == LUA_TNUMBER);
  pushValue(L, 1.0f);
  assert(lua_type(L, -1) == LUA_TNUMBER);
  pushValue(L, 1.0);
  assert(lua_type(L, -1) == LUA_TNUMBER);
  pushValue(L, "Hola");
  assert(lua_type(L, -1) == LUA_TSTRING);
  lua_CFunction holaFunction = (lua_State* L) {return 0;};
  pushValue(L, holaFunction);
  assert(lua_type(L, -1) == LUA_TFUNCTION);
  state.pop(8);
  pushValue(L, "Hola como estas");
  state.setGlobal("Greeting");
  state.getGlobal("Greeting");
  assert(lua_type(L, -1) == LUA_TSTRING);
  assert(fromStringz(lua_tostring(L, 1)) == "Hola como estas");
  lua_pop(L, 1);
}