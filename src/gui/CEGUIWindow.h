#pragma once

#include <CEGUI/CEGUI.h>
#include <OgreVector2.h>
/*

// We can't just capture the luaInitializer in the lambda here, because
    // luabind::object's call operator is not const
    auto initializer = std::bind<void>(
        [](luabind::object luaInitializer) {
            luaInitializer();
        },
        luaInitializer
    );
*/

namespace luabind {
class scope;
}

namespace thrive {

class CEGUIWindow {

public:

    /**
    * Destructor
    **/
    virtual
    ~CEGUIWindow();

    static CEGUIWindow
    getRootWindow();

    /**
    * @brief Lua bindings
    *
    * Exposes:
    * - OgreSceneNodeComponent()
    * - @link m_transform transform @endlink
    * - Transform
    *   - Transform::orientation
    *   - Transform::position
    *   - Transform::scale
    * - OgreSceneNodeComponent::attachObject
    * - OgreSceneNodeComponent::detachObject
    * - OgreSceneNodeComponent::m_parentId (as "parent")
    *
    * @return
    */
    static luabind::scope
    luaBindings();

    /**
    * @brief Get the underlying cegui windows text if it has any
    *
    * @return text
    *  The requested text or empty string if none exist
    */
    std::string
    getText() const;

    /**
    * @brief Sets the underlying cegui windows text
    *
    * @param text
    *  The value to set the text to
    */
    void
    setText(
        const std::string& text
    );

    /**
    * @brief Appends to the underlying cegui windows text
    *
    * @param text
    *  The text to append
    */
    void
    appendText(
        const std::string& text
    );

    /**
    * @brief Gets the underlying cegui windows parent, wrapped as a CEGUIWindow*
    *
    * @return window
    */
    CEGUIWindow
    getParent() const;

    /**
    * @brief Gets one of the underlying cegui windows children by name, wrapped as a CEGUIWindow*
    *
    * @param name
    *  name of the child to acquire
    *
    * @return window
    */
    CEGUIWindow
    getChild(
        const std::string& name
    ) const;

    /**
    * @brief Gets one of the underlying cegui windows children by name, wrapped as a CEGUIWindow*
    *
    * @param eventName
    *  name of the event to subscribe to
    *
    * @param callback
    *  callback to use when event fires
    */
    void
    RegisterEventHandler(
        const std::string& eventName,
        CEGUI::Event::Subscriber callback
    );

    /**
    * @brief Enables the window, allowing interaction
    **/
    void
    enable();

    /**
    * @brief Disables interaction with the window
    **/
    void
    disable();

    /**
    * @brief Sets focus to the underlying cegui window
    **/
    void
    setFocus();

    /**
    * @brief Makes the window visible
    **/
    void
    show();

    /**
    * @brief Hides the window
    **/
    void
    hide();

    /**
    * @brief Moves the window in front of all other windows
    **/
    void
    moveToFront();

    /**
    * @brief Moves the window behind all other windows
    **/
    void
    moveToBack();

    /**
    * @brief Moves the window in front of target window
    *
    * @param target
    *  The window to move in front of
    **/
    void
    moveInFront(
        const CEGUIWindow& target
    );

    /**
    * @brief Moves the window behind target window
    *
    * @param target
    *  The window to move behind
    **/
    void
    moveBehind(
        const CEGUIWindow& target
    );

    /**
    * @brief Sets the windows position
    *
    * The positional system uses Falagard coordinate system.
    * The position is offset from one of the corners and edges of this Element's parent element (depending on alignments)
    *
    * @param position
    *  The new position to use
    **/
    void
    setPosition(
        Ogre::Vector2 position
    );



private:

    //Private constructor
    CEGUIWindow(CEGUI::Window* window);

    CEGUI::Window* m_window = nullptr;

};

}
