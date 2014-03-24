#include "gui/script_bindings.h"

#include "scripting/luabind.h"
#include "gui/CEGUIWindow.h"

luabind::scope
thrive::GuiBindings::luaBindings() {
    return (
        // Other
        CEGUIWindow::luaBindings()
    );
}


