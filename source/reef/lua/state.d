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
    if(is_owner)
      (() @trusted => lua_close(state))();
  }
  @trusted void doFile(string file)
  {
    if(luaL_dofile(state, toStringz(file)) != 0)
      printError(this);
  }
  @trusted void doString(string line)
  {
    if(luaL_dostring(state, toStringz(line)) != 0)
      printError(this);
  }
  @trusted void openLibs()
  {
    luaL_openlibs(state);
  }
  @trusted void require(const string filename)
  {
    if(requireFile(state, toStringz(filename)) != 0)
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
  @safe void setGlobal(string name)
  {
    reef.lua.stack.setGlobal(state, name);
  }
  @safe void getGlobal(string name)
  {
    reef.lua.stack.getGlobal(state, name);
  }
  @property
  @safe lua_State* state()
  {
    if(luastate)
      return luastate;
    throw new Exception("lua state is null");
  }
  private lua_State* luastate;
  bool is_owner;
}

import std.stdio : writeln;
package @trusted void printError(State state)
{
  writeln(fromStringz(lua_tostring(state.state, -1)));
}
private:
int requireFile (lua_State *L, const char *name) {
  lua_getglobal(L, "require");
  lua_pushstring(L, name);
  return report(L, lua_pcall(L, 1, 1, 0));
}
int report(lua_State* L, int status)
{
	if (status && !lua_isnil(L, -1)) {
    string msg = cast(string)fromStringz(lua_tostring(L, -1));
    if (msg == null) msg = "(error object is not a string)";
		writeln(msg);
		lua_pop(L, 1);
	}
	return status;
}