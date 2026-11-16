#include <stdio.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
int main(int argc, char **argv) {
    lua_State *L = luaL_newstate();
    if (!L) return 2;
    luaL_openlibs(L);
    int status = luaL_dofile(L, argc > 1 ? argv[1] : "tests/run.lua");
    if (status) fprintf(stderr, "%s\n", lua_tostring(L, -1));
    lua_close(L);
    return status ? 1 : 0;
}
