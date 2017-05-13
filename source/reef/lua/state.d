module reef.lua.state;

import std.string;

import luad.c.all;
import reef.lua.classes : registerClassType = registerClass;
import reef.lua.stack;
import reef.lua.exception;

class State
{
  @safe this()
  {
    luastate = (() @trusted => luaL_newstate)();
    if(luastate is null)
      throw new Exception("Failed to instantiate luastate");
    is_owner = true;
  }
  package @safe this(lua_State* L)
  {
    if(L is null)
      throw new StateException("Passing null to State()");
    is_owner = false;
    luastate = L;
  }
  @safe this(State other)
  {
    if(other is null)
      throw new StateException("Cannot copy null state");
    this(other.state);
  }
  @safe ~this()
  {
    if(is_owner && !(state is null))
      (() @trusted => lua_close(state))();
  }
  /**
   * Load a file for execution
   * Params:
   * file, non null string
   */
  @safe void doFile(string file)
  {
    if(file is null)
      throw new StateException("Cannot pass null to doFile");
    if((() @trusted => luaL_dofile(state, toStringz(file)))() != 0)
      printError(this);
  }
  @safe void doString(string line)
  {
    if(line is null)
      throw new StateException("Cannot pass null to doString");
    if((() @trusted => luaL_dostring(state, toStringz(line)))() != 0)
      printError(this);
  }
  /**
   * This function does not add a suffix - it is left to the user
   * this way the user can add .lua or .moon suffix to their path
   */
  @safe void addPath(string path)
  {
    doString("package.path = package.path .. ';' .. '"~path~"'");
  }
  /**
   * On windows this functions adds the dll suffix to your path. On linux/mac it will at so
   */
  @safe void addCPath(string path)
  {
    version(Windows) {
      doString("package.cpath = package.cpath .. ';"~path~"/?.dll'");
    }
    version(MinGW) {
      doString("package.cpath = package.cpath .. ';"~path~"/?.dll'");
    }
    // linux/mac
    else {
      doString("package.cpath = package.cpath .. ';"~path~"/?.so'");
    }
  }
  @safe void openLibs()
  {
    (() @trusted => luaL_openlibs(state))();
  }
  @safe void require(string filename)
  {
    if(requireFile(this, filename) != 0)
      throw new Exception("Lua related exception");
  }
  @trusted void registerClass(T)()
  {
    registerClassType!T(this);
  }
  @trusted void push(T)(T value)
  {
    pushValue!T(state, value);
  }
  @safe void pop(int index)
  {
    (() @trusted => lua_pop(state, index))();
  }
  @safe void setGlobal(string name)
  {
    if(!(name is null))
      (() @trusted => lua_setglobal(state, toStringz(name)))();
    else
      throw new StateException("Lua state or name for global to be set were null");
  }
  @safe void getGlobal(string name)
  {
    if(!(name is null))
      (() @trusted => lua_getglobal(state, toStringz(name)))();
    else
      throw new StateException("Lua state or name for global to get were null");
  }
  @safe bool isNil(int index)
  {
    return (() @trusted => cast(bool)lua_isnil(state, index))();
  }
  @property
  @safe @nogc lua_State* state() nothrow
  {
    return luastate;
  }
  private lua_State* luastate;
  bool is_owner;
}

import std.stdio : writeln;
package @safe void printError(State state)
{
  writeln((() @trusted => fromStringz(luaL_checkstring(state.state, -1)))());
  state.pop(1);
}
private @safe int requireFile (State state, string name) {
  state.getGlobal("require");
  state.push(name);
  return report(state, (() @trusted => lua_pcall(state.state, 1, 1, 0))());
}
private @safe int report(State state, int status)
{
	if(status != 0 && !state.isNil(-1))
    printError(state);
	return status;
}

unittest
{
  import std.exception;
  assertThrown!StateException(new State(cast(lua_State*)null), "State object with null lua_State* should have failed");
  assertThrown!StateException(new State(cast(State)null), "State object with null State should have failed");
  auto state = new State();
  assert(!(state is null), "state should not be null");
  assert(!(state.state is null), "state.state should not be null");
  assertThrown!StateException(state.setGlobal(null), "setGlobal should have thrown because null passed to arg 0");
  assertThrown!StateException(state.getGlobal(null), "getGlobal should have thrown because null passed to arg 0");
  assertNotThrown!StateException(state.getGlobal("barry"), "getGlobal shouldn't have thrown when trying to get non existant global: barry");
  assert(state.isNil(-1), "The top of the stack should have been nil after trying to get non existant global");
  state.pop(1);
  state.push("Hola");
  assert(lua_type(state.state, -1) == LUA_TSTRING, "Lua type should have been a string");
  state.pop(1);
}