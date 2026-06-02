#include "GdiFontManager.h"

int CALLBACK EnumFontFamExProc(const LOGFONT* lpelfe, const TEXTMETRIC* lpntme, DWORD FontType, LPARAM lParam)
{
    *((LPARAM*)lParam) = 1;
    return 1;
}

extern "C"
{
    extern __declspec(dllexport) GdiFontManager* CreateFontManager(IDirect3DDevice8* pDirect3DDevice)
    {
        return new GdiFontManager(pDirect3DDevice);
    }
    extern __declspec(dllexport) void DestroyFontManager(GdiFontManager* pFontManager)
    {
        delete pFontManager;
    }
    extern __declspec(dllexport) GdiFontReturn_t CreateTexture(GdiFontManager* pFontManager, GdiFontData_t* data)
    {
        return pFontManager->CreateFontTexture(*data);
    }
    extern __declspec(dllexport) GdiFontReturn_t CreateTextureColor(GdiFontManager* pFontManager, GdiFontData_t* data)
    {
        return pFontManager->CreateFontTextureColor(*data);
    }
    extern __declspec(dllexport) GdiFontReturn_t CreateRectTexture(GdiFontManager* pFontManager, GdiRectData_t* data)
    {
        return pFontManager->CreateRectTexture(*data);
    }
    extern __declspec(dllexport) bool GetFontAvailable(const char* font)
    {
        LOGFONT lf = {0};
        lf.lfCharSet = DEFAULT_CHARSET;
        swprintf_s(lf.lfFaceName, 32, L"%S", font);
        LPARAM lParam = 0;
        ::EnumFontFamiliesEx(GetDC(nullptr), &lf, EnumFontFamExProc, (LPARAM)&lParam, 0);
        return lParam ? true : false;
    }
    extern __declspec(dllexport) void EnableTextureDump(GdiFontManager* pFontManager, const char* folder)
    {
        pFontManager->EnableTextureDump(folder);
    }
    extern __declspec(dllexport) void DisableTextureDump(GdiFontManager* pFontManager)
    {
        pFontManager->DisableTextureDump();
    }
}

// ===================================================================
// Native chat-input-bar hide hook (FancyChat Phase 2).
//
// FFXI draws the inline element via  element->vtable[0x10]()  from the
// parent widget's draw routine (seen at FFXiMain.dll+117C32:
// mov edx,[ecx]; call [edx+10], no args -> __thiscall(this)).  Menu
// elements are C++ objects whose vtable lives at [element+0], and for the
// inline chat-input prompt that vtable is heap-resident (writable).  We
// swap vtable[0x10] for HookRender, which returns immediately (skipping
// the draw) when suppression is on AND `this` is the element the addon
// flagged as the input bar this frame.  Single-pointer, reversible patch;
// undone when the vtable changes, on RemoveInputBarHook, and on DLL detach.
//
// (vtable[0x28], called from the menu manager with an `active` arg, turned
// out to be a non-draw method -- skipping it had no visual effect.)
//
// vtable[0x10] is __thiscall(this); we intercept as __fastcall(this, edx)
// with no stack args, matching the call site's stack layout.
// ===================================================================
static const uint32_t kRenderSlot = 0x10;  // vtable byte offset of draw()
typedef void* (__fastcall* RenderFn_t)(void* self, void* edx);

static bool       g_barSuppress  = false;
static uint32_t   g_barElement   = 0;  // an inline element (used to find the vtable)
static uint32_t   g_inlineMenuID = 0;  // MenuID of the inline menu; elements store it at +0x08
static uint32_t   g_barVtable    = 0;  // vtable we patched (0 = none)
static RenderFn_t g_barOrig      = nullptr;

// Diagnostics (read via InputBarStat).
static volatile uint32_t g_renderCalls = 0;  // HookRender invocations
static volatile uint32_t g_renderSkips = 0;  // times we skipped the draw
static volatile uint32_t g_lastThis    = 0;  // last `self` seen

static void* __fastcall HookRender(void* self, void* edx)
{
    g_renderCalls++;
    g_lastThis = reinterpret_cast<uint32_t>(self);
    if (g_barSuppress && self != nullptr && g_inlineMenuID != 0)
    {
        // Skip every element whose owning MenuID (at +0x08) is the inline
        // menu's — i.e. the whole input bar (box + text + cursor), not just
        // the one child element.
        uint32_t ownerMenu = 0;
        __try { ownerMenu = *reinterpret_cast<uint32_t*>(reinterpret_cast<uint8_t*>(self) + 0x08); }
        __except (EXCEPTION_EXECUTE_HANDLER) { ownerMenu = 0; }
        if (ownerMenu == g_inlineMenuID)
        {
            g_renderSkips++;
            return nullptr;             // skip drawing this inline-menu element
        }
    }
    if (g_barOrig != nullptr)
        return g_barOrig(self, edx);
    return nullptr;
}

static void RestoreBarHook()
{
    if (g_barVtable != 0 && g_barOrig != nullptr)
    {
        uint32_t* slot = reinterpret_cast<uint32_t*>(g_barVtable + kRenderSlot);
        DWORD op;
        if (VirtualProtect(slot, sizeof(uint32_t), PAGE_EXECUTE_READWRITE, &op))
        {
            *slot = reinterpret_cast<uint32_t>(g_barOrig);
            VirtualProtect(slot, sizeof(uint32_t), op, &op);
        }
    }
    g_barVtable = 0;
    g_barOrig   = nullptr;
}

static void EnsureBarHook(uint32_t element)
{
    if (element == 0)
        return;

    uint32_t vtable = 0;
    __try { vtable = *reinterpret_cast<uint32_t*>(element); }
    __except (EXCEPTION_EXECUTE_HANDLER) { return; }

    if (vtable == 0 || vtable == g_barVtable)
        return;                         // bad pointer, or already hooked

    RestoreBarHook();                   // vtable changed -> undo prior patch

    uint32_t* slot = reinterpret_cast<uint32_t*>(vtable + kRenderSlot);
    DWORD oldProt;
    if (VirtualProtect(slot, sizeof(uint32_t), PAGE_EXECUTE_READWRITE, &oldProt))
    {
        g_barOrig = reinterpret_cast<RenderFn_t>(*slot);
        *slot     = reinterpret_cast<uint32_t>(&HookRender);
        VirtualProtect(slot, sizeof(uint32_t), oldProt, &oldProt);
        g_barVtable = vtable;
    }
}

extern "C"
{
    // Called each frame by the addon.
    //   element  = inline input element address (0 when not applicable)
    //   suppress = panel-enabled && input-open
    extern __declspec(dllexport) void UpdateInputBarHook(uint32_t element, uint32_t menuID, int suppress)
    {
        g_barElement   = element;
        g_inlineMenuID = menuID;
        g_barSuppress  = (suppress != 0);
        if (element != 0)
            EnsureBarHook(element);     // element only used to locate the vtable
    }

    // Called on addon unload to remove the patch before our code unloads.
    extern __declspec(dllexport) void RemoveInputBarHook()
    {
        g_barSuppress  = false;
        g_barElement   = 0;
        g_inlineMenuID = 0;
        RestoreBarHook();
    }

    // Diagnostic readout.
    //   0 = patched vtable, 1 = flagged element, 2 = HookRender calls,
    //   3 = skips, 4 = last `this`, 5 = suppress flag, 6 = saved original fn
    extern __declspec(dllexport) uint32_t InputBarStat(int which)
    {
        switch (which)
        {
            case 0: return g_barVtable;
            case 1: return g_barElement;
            case 2: return g_renderCalls;
            case 3: return g_renderSkips;
            case 4: return g_lastThis;
            case 5: return g_barSuppress ? 1u : 0u;
            case 6: return reinterpret_cast<uint32_t>(g_barOrig);
            default: return 0u;
        }
    }
}

BOOL WINAPI DllMain(HINSTANCE, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_DETACH)
        RestoreBarHook();
    return TRUE;
}