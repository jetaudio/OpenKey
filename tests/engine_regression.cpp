#include "Engine.h"
#include <iostream>
#include <cstdlib>

#include "test_config.h"

static int assertions = 0;
static void expect(bool condition, const std::string& label) {
    ++assertions;
    if (!condition) { std::cerr << "FAIL: " << label << '\n'; std::exit(1); }
}

static void resetConversion() {
    convertToolToAllCaps = convertToolToAllNonCaps = false;
    convertToolToCapsFirstLetter = convertToolToCapsEachWord = convertToolRemoveMark = false;
    convertToolFromCode = convertToolToCode = 0;
}

static std::string convert(const std::string& text, int from, int to) {
    convertToolFromCode = (Uint8)from;
    convertToolToCode = (Uint8)to;
    return convertUtil(text);
}

int main() {
    resetConversion();
    expect(convertUtil(u8"Đặng THỊ Ánh Mixed ASCII") == u8"Đặng THỊ Ánh Mixed ASCII", "preserve original case");
    convertToolRemoveMark = true;
    expect(convertUtil(u8"ĐẶNG Thị Ánh Ước MƠ") == "DANG Thi Anh Uoc MO", "remove marks while preserving case");
    convertToolToAllCaps = true;
    expect(convertUtil(u8"Đặng Thị ánh") == "DANG THI ANH", "remove marks and uppercase");
    convertToolToAllCaps = false;
    convertToolToAllNonCaps = true;
    expect(convertUtil(u8"ĐẶNG Thị Ánh") == "dang thi anh", "remove marks and lowercase");
    convertToolToAllNonCaps = false;
    convertToolToCapsEachWord = true;
    expect(convertUtil(u8"đẶNG tHỊ áNH") == "Dang Thi Anh", "remove marks and capitalize words");
    convertToolToCapsEachWord = false;
    convertToolToCapsFirstLetter = true;
    expect(convertUtil(u8"đẶNG tHỊ. áNH\nước MƠ") == "Dang thi. Anh\nUoc mo", "capitalize sentences");
    resetConversion();

    // Every mapped Vietnamese character, all 25 source/destination pairs.
    for (const auto& row : _codeTable[0]) {
        for (size_t column = 0; column < row.second.size(); ++column) {
            Uint16 character = row.second[column];
            if (character == 0) continue; // Unused table slots.
            std::string original = wideStringToUtf8(std::wstring(1, character));
            for (int from = 0; from < 5; ++from) {
                std::string encoded = convert(original, 0, from);
                for (int to = 0; to < 5; ++to) {
                    std::string converted = convert(encoded, from, to);
                    std::string decoded = convert(converted, to, 0);
                    std::string expected = original;
                    if ((from == 1 || to == 1) && column % 2 == 0 &&
                        _codeTable[1][row.first][column] == _codeTable[1][row.first][column + 1]) {
                        expected = wideStringToUtf8(std::wstring(1, row.second[column + 1]));
                    }
                    expect(decoded == expected, "roundtrip U+" + std::to_string(character) +
                        " from " + std::to_string(from) + " to " + std::to_string(to));
                }
            }
        }
    }
    const std::string mixed = u8"Đặng THỊ Ánh, Ước MƠ! Ê Ắ Ấ Ỗ Ự Ỳ. Mixed ASCII 123 🚀";
    for (int code = 0; code < 5; ++code) {
        std::string encoded = convert(mixed, 0, code);
        std::string expected = code == 1 ? u8"Đặng THị ánh, Ước MƠ! Ê ắ ấ ỗ ự ỳ. Mixed ASCII 123 🚀" : mixed;
        expect(convert(encoded, code, 0) == expected, "mixed text roundtrip " + std::to_string(code));
        convertToolRemoveMark = true;
        expected = code == 1 ? u8"Dang THi anh, Uoc MO! E a a o u y. Mixed ASCII 123 🚀" : u8"Dang THI Anh, Uoc MO! E A A O U Y. Mixed ASCII 123 🚀";
        expect(convert(encoded, code, 0) == expected,
            "mixed text remove marks " + std::to_string(code));
        convertToolRemoveMark = false;
    }
    expect(convert("Keep This", 255, 0) == "Keep This", "invalid source encoding");
    expect(convert("Keep This", 0, 255) == "Keep This", "invalid target encoding");

    initSmartSwitchKey(nullptr, 0);
    const int packed = 1 | (3 << 1);
#if !defined(_WIN32) && !defined(LINUX)
    expect(getAppInputMethodStatus("com.apple.Terminal", packed) == (3 << 1), "developer default preserves code table");
#else
    expect(getAppInputMethodStatus("com.apple.Terminal", packed) == -1, "mac defaults do not affect Windows");
#endif
    setAppInputMethodStatus("com.apple.Terminal", packed);
    expect(getAppInputMethodStatus("com.apple.Terminal", 0) == packed, "explicit app preference wins");
    std::vector<Byte> saved;
    getSmartSwitchKeySaveData(saved);
    initSmartSwitchKey(saved.data(), (int)saved.size());
    expect(getAppInputMethodStatus("com.apple.Terminal", 0) == packed, "saved preference roundtrip");
    initSmartSwitchKey(nullptr, 0);
    expect(getAppInputMethodStatus("ordinary.app", packed) == -1, "new app inherits current language");
    expect(getAppInputMethodStatus("ordinary.app", 0) == packed, "new app keeps packed state");
    initSmartSwitchKey(nullptr, 0);
    expect(getAppInputMethodStatus("ordinary.app", 0) == -1, "reinitialization clears cache");
    const Byte truncated[] = {1, 0, 255, 'x'};
    initSmartSwitchKey(truncated, sizeof(truncated));
    getSmartSwitchKeySaveData(saved);
    expect(saved.size() == 2, "truncated preference data is ignored safely");
    expect(getAppInputMethodStatus("", packed) == -1, "unknown app does not become preference");
    std::cout << "Engine regression tests: " << assertions << " assertions passed.\n";
}
