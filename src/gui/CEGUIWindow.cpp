#include "gui/CEGUIWindow.h"

#include "scripting/luabind.h"

using namespace thrive;


// Static member
CEGUIWindow
CEGUIWindow::getRootWindow()
{
    return CEGUIWindow(CEGUI::System::getSingleton().getDefaultGUIContext().getRootWindow());
}


CEGUIWindow::CEGUIWindow(
    CEGUI::Window* window
) : m_window(window)
{
}


CEGUIWindow::~CEGUIWindow()
{
}

luabind::scope
CEGUIWindow::luaBindings() {
    using namespace luabind;
    return class_<CEGUIWindow>("CEGUIWindow")
        .scope
        [
            def("getRootWindow", &CEGUIWindow::getRootWindow)
        ]
        .def("getText", &CEGUIWindow::getText)
        .def("setText", &CEGUIWindow::setText)
        .def("appendText", &CEGUIWindow::appendText)
        .def("getParent", &CEGUIWindow::getParent)
        .def("getChild", &CEGUIWindow::getChild)
        .def("RegisterEventHandler", &CEGUIWindow::RegisterEventHandler)
        .def("enable", &CEGUIWindow::enable)
        .def("disable", &CEGUIWindow::disable)
        .def("setFocus", &CEGUIWindow::setFocus)
        .def("show", &CEGUIWindow::show)
        .def("hide", &CEGUIWindow::hide)
        .def("moveToFront", &CEGUIWindow::moveToFront)
        .def("moveToBack", &CEGUIWindow::moveToBack)
        .def("moveInFront", &CEGUIWindow::moveInFront)
        .def("moveBehind", &CEGUIWindow::moveBehind)
        .def("setPosition", &CEGUIWindow::setPosition)
    ;
}


std::string
CEGUIWindow::getText() const {
    return std::string(m_window->getText().c_str());
}


void
CEGUIWindow::setText(
    const std::string& text
) {
    m_window->setText(text);
}


void
CEGUIWindow::appendText(
    const std::string& text
) {
    m_window->appendText(text);
}


CEGUIWindow
CEGUIWindow::getParent() const {
    return CEGUIWindow(m_window->getParent());
}


CEGUIWindow
CEGUIWindow::getChild(
    const std::string& name
) const  {
    return CEGUIWindow(m_window->getChild(name));
}


void
CEGUIWindow::RegisterEventHandler(
    const std::string& eventName,
    CEGUI::Event::Subscriber callback
) {
    m_window->subscribeEvent(eventName, callback);
}


void
CEGUIWindow::enable(){
    m_window->enable();
}


void
CEGUIWindow::disable(){
    m_window->disable();
}


void
CEGUIWindow::setFocus() {
    m_window->activate();
}


void
CEGUIWindow::show(){
    m_window->show();
}


void
CEGUIWindow::hide(){
    m_window->hide();
}


void
CEGUIWindow::moveToFront(){
    m_window->moveToFront();
}


void
CEGUIWindow::moveToBack(){
    m_window->moveToBack();
}


void
CEGUIWindow::moveInFront(
    const CEGUIWindow& target
){
    m_window->moveInFront(target.m_window);
}


void
CEGUIWindow::moveBehind(
    const CEGUIWindow& target
){
    m_window->moveBehind(target.m_window);
}


void
CEGUIWindow::setPosition(
    Ogre::Vector2 position
){
    m_window->setPosition(CEGUI::Vector2<CEGUI::UDim>(CEGUI::UDim(position.x, 0), CEGUI::UDim(position.y, 0)));
}
