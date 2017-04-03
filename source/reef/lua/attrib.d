module reef.lua.attrib;

/// Specifies the type of method that the binding will deal with
enum MethodType : string
{
  none = "none_method",
  func = "function",
  method = "method",
  ctor = "ctor"
}
/// Specifies the kind of return value the binding will deal in
enum RetType : string
{
  none = "none_rettype",
  lightud = "lightud_rettype",
  userdat = "userdat_rettype",
  str = "string",
  number = "number"
}
/// Specifies the type of data that the binding should treat as
enum MemberType : string
{
  none = "none_memtype",
  lightud = "lightud_memtype",
  userdat = "userdat_memtype",
}
/// Declare above desired field to have the luabinding pick it up
/// For classes, only the name field matters
struct LuaExport
{
  /// Name that luad should use (unimplemented yet)
  string name = "";
  /// Help the exporting routine distinguish things like userdata vs lightuserdata
  MethodType type;
  /// Sub-member to refer to during the exporting routine
  string submember = "";
  /// Return type to put on the stack
  RetType rtype;
  /// Member type
  MemberType memtype;
}

unittest
{
  @LuaExport("variable_x", MethodType.ctor, "mangleof", RetType.number, MemberType.none)
  int hola;

  import std.traits : hasUDA, getUDAs;
  static assert(hasUDA!(hola, LuaExport), "variable hola, should at compile time have LuaExport UDA");
  assert(hasUDA!(hola, LuaExport), "variable hola should have LuaExport UDA");
  enum holaUda = getUDAs!(hola, LuaExport)[0];
  static assert(holaUda.name == "variable_x", "UDA name should be equal at compile time");
  static assert(holaUda.type == MethodType.ctor, "holaUda.type should equal MethodType.ctor at compile time");
  static assert(holaUda.submember == "mangleof", "holaUda.submember should equal 'mangleof' at compile time");
  static assert(holaUda.rtype == RetType.number, "holaUda.rtype should equal RetType.number at compile time");
  static assert(holaUda.memtype == MemberType.none, "holaUda.memtype should equal MemberType.none at compile time");
  assert(holaUda.name == "variable_x", "UDA name should be equal");
  assert(holaUda.type == MethodType.ctor, "holaUda.type should equal MethodType.ctor");
  assert(holaUda.submember == "mangleof", "holaUda.submember should equal 'mangleof'");
  assert(holaUda.rtype == RetType.number, "holaUda.rtype should equal RetType.number");
  assert(holaUda.memtype == MemberType.none, "holaUda.memtype should equal MemberType.none");
}