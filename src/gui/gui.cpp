#include "gui/gui.h"
#include <CEGUI/CEGUI.h>
#include "CEGUI/RendererModules/Ogre/Renderer.h"


void testgui(){
/*
    CEGUI::OgreRenderer* renderer = &CEGUI::OgreRenderer::bootstrapSystem();
    CEGUI::SchemeManager::getSingleton().create( "TaharezLook.scheme" );
    CEGUI::System::getSingleton().setDefaultFont( "DejaVuSans-10" );
    CEGUI::System::getSingleton().setDefaultMouseCursor( "TaharezLook", "MouseArrow" );

    CEGUI::Window* myRoot = CEGUI::WindowManager::getSingleton().createWindow( "DefaultWindow", "_MasterRoot" );
    CEGUI::System::getSingleton().setGUISheet( myRoot );*/



//
    CEGUI::OgreRenderer* renderer = &CEGUI::OgreRenderer::bootstrapSystem();

  // CEGUI::Imageset::setDefaultResourceGroup("Imagesets");
   /* CEGUI::Font::setDefaultResourceGroup("Fonts");
    CEGUI::Scheme::setDefaultResourceGroup("Schemes");
    CEGUI::WindowManager::setDefaultResourceGroup("Layouts");
    CEGUI::WidgetLookManager::setDefaultResourceGroup("LookNFeel");*/

    CEGUI::FontManager::getSingleton().createFromFile("Jura-13.font");

    CEGUI::SchemeManager::getSingleton().createFromFile("TaharezLook.scheme");
    CEGUI::SchemeManager::getSingleton().createFromFile("VanillaSkin.scheme");
    CEGUI::SchemeManager::getSingleton().createFromFile("WindowsLook.scheme");
    CEGUI::SchemeManager::getSingleton().createFromFile("Generic.scheme");
    CEGUI::SchemeManager::getSingleton().createFromFile("HUDDemo.scheme");
 CEGUI::FontManager::getSingleton().createFromFile("Jura-13.font");

    CEGUI::ImageManager::getSingleton().loadImageset("DriveIcons.imageset");
    CEGUI::ImageManager::getSingleton().loadImageset("GameMenu.imageset");
    CEGUI::Window *newWindow = CEGUI::WindowManager::getSingleton().loadLayoutFromFile("VanillaConsole.layout");

    // set up defaults
    CEGUI::System::getSingleton().getDefaultGUIContext().getMouseCursor().setDefaultImage("WindowsLook/MouseArrow");

    // load the drive icons imageset


      std::cout << renderer << std::endl;
    CEGUI::WindowManager& wmgr = CEGUI::WindowManager::getSingleton();
    CEGUI::Window* myRoot = wmgr.createWindow( "DefaultWindow", "root" );
    CEGUI::System::getSingleton().getDefaultGUIContext().setRootWindow( myRoot );
  //   CEGUI::FrameWindow* fWnd = static_cast<CEGUI::FrameWindow*>(
    //wmgr.createWindow( "TaharezLook/FrameWindow", "testWindow" ));
   // myRoot->addChild( fWnd );
   myRoot->addChild(newWindow);
    // position a quarter of the way in from the top-left of parent.
//fWnd->setPosition( CEGUI::UVector2( CEGUI::UDim( 0.25f, 0.0f ), CEGUI::UDim( 0.25f, 0.0f ) ) );
// set size to be half the size of the parent
//fWnd->setSize( CEGUI::USize( CEGUI::UDim( 0.5f, 0.0f ), CEGUI::UDim( 0.5f, 0.0f ) ) );
//fWnd->setText( "Hello World!" );

}
