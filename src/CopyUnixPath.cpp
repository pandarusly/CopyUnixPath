// CopyUnixPath.cpp
#include <windows.h>
#include <string>
#include <vector>

struct Rule {
    std::wstring match;
    std::wstring replace;
};

static std::vector<Rule> LoadRules() {
    std::vector<Rule> rules;

    // Config file: CopyUnixPath.ini in the same directory as the exe
    wchar_t configPath[MAX_PATH];
    GetModuleFileNameW(NULL, configPath, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(configPath, L'\\');
    if (lastSlash) {
        *(lastSlash + 1) = L'\0';
        wcscat_s(configPath, MAX_PATH, L"CopyUnixPath.ini");
    }

    // Read all keys under [Rules] section (double-null-terminated list)
    wchar_t keys[8192] = {};
    DWORD len = GetPrivateProfileStringW(L"Rules", NULL, NULL, keys, 8192, configPath);
    if (len == 0) return rules;

    wchar_t* p = keys;
    while (*p) {
        wchar_t value[2048] = {};
        GetPrivateProfileStringW(L"Rules", p, L"", value, 2048, configPath);

        // Value format: match>replace
        wchar_t* sep = wcschr(value, L'>');
        if (sep && sep != value) {
            *sep = L'\0';
            Rule rule;
            rule.match = value;
            rule.replace = sep + 1;
            rules.push_back(rule);
        }

        p += wcslen(p) + 1;
    }

    return rules;
}

static std::wstring ApplyReplacements(const std::wstring& path) {
    std::vector<Rule> rules = LoadRules();
    std::wstring result = path;
    for (const auto& rule : rules) {
        size_t pos = result.find(rule.match);
        if (pos != std::wstring::npos) {
            result.replace(pos, rule.match.size(), rule.replace);
        }
    }
    return result;
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmd, int nShow) {
    // Get wide command line
    LPWSTR cmdLine = GetCommandLineW();
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(cmdLine, &argc);
    
    if (argc < 2) {
        LocalFree(argv);
        return 0;
    }
    
    // Get first argument (the path)
    std::wstring path = argv[1];
    LocalFree(argv);
    
    // Remove quotes
    if (!path.empty() && path[0] == L'"') {
        path.erase(0, 1);
    }
    if (!path.empty() && path[path.size() - 1] == L'"') {
        path.erase(path.size() - 1);
    }
    
    // Apply fixed path replacements (before slash conversion, match Windows backslash paths)
    path = ApplyReplacements(path);

    // Backslash to forward slash
    for (size_t i = 0; i < path.size(); i++) {
        if (path[i] == L'\\') {
            path[i] = L'/';
        }
    }

    // Copy to clipboard
    if (OpenClipboard(NULL)) {
        EmptyClipboard();

        size_t len = path.size() + 1;
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, len * sizeof(wchar_t));

        if (hMem) {
            wchar_t* pMem = (wchar_t*)GlobalLock(hMem);
            if (pMem) {
                wcscpy_s(pMem, len, path.c_str());
                GlobalUnlock(hMem);
                if (!SetClipboardData(CF_UNICODETEXT, hMem)) {
                    GlobalFree(hMem);
                }
            } else {
                GlobalFree(hMem);
            }
        }

        CloseClipboard();
    }
    
    return 0;
}