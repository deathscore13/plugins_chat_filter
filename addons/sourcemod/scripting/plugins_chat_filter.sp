#include <sourcemod>
#include <macros>
#include <regex>

#define REGEX_MAXLEN        256     /**< Максимальный размер регулярных выражений */
#define REGEX_MAXLEN_CON    "256"   /**< Максимальный размер регулярных выражений (строка) */

#define FLAG_NONE           0   /**< No flags */
#define FLAG_CASELESS       1   /**< Ignore Case */
#define FLAG_MULTILINE      2   /**< Multilines (affects ^ and $ so that they match the start/end of a line rather than matching the start/end of the string). */
#define FLAG_DOTALL         3   /**< Single line (affects . so that it matches any character, even new line characters). */
#define FLAG_EXTENDED       4   /**< Pattern extension (ignore whitespace and # comments). */
#define FLAG_ANCHORED       5   /**< Force pattern anchoring. */
#define FLAG_DOLLAR_ENDONLY 6   /**< $ not to match newline at end. */
#define FLAG_UNGREEDY       7   /**< Invert greediness of quantifiers */
#define FLAG_NOTEMPTY       8   /**< An empty string is not a valid match. */
#define FLAG_UTF8           9   /**< Use UTF-8 Chars */
#define FLAG_NO_UTF8_CHECK  10  /**< Do not check the pattern for UTF-8 validity (only relevant if PCRE_UTF8 is set) */
#define FLAG_UCP            11  /**< Use Unicode properties for \ed, \ew, etc. */

#define FLAGS_DELIMETER     ','     /**< Разделитель флагов для их перечисления */

int iCount;
DataPack hPack;

public Plugin myinfo =
{
    name = "Plugins Chat-Filter",
    description = "Message filter with support for plugins working with OnClientSayCommand_Post",
    author = "DeathScore13",
    version = "1.0.0",
    url = "https://github.com/deathscore13/plugins_chat_filter"
};

public void OnPluginStart()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sz(path), "configs/plugins_chat_filter.cfg");
    KeyValues kv = new KeyValues("plugins_chat_filter");
    if (!FileExists(path))
    {
        kv.JumpToKey("0", true);
        {
            kv.SetString("pattern", "(?<!\\d)(?:(?:2[0-5][0-5]|1\\d\\d|[1-9]\\d|\\d)\\.){3}(?:2[0-5][0-5]|1\\d\\d|[1-9]\\d|\\d)(?!\\d)");
            kv.SetString("flags", "0");
            kv.SetString("match", "1");
        }
        kv.Rewind();

        kv.JumpToKey("1", true);
        {
            kv.SetString("pattern", "(?:https?:\\/\\/)?(?:www\\.)?(?:\\S+\\.)+\\S+\\/\\S*|(?:https?:\\/\\/|www\\.)(?:\\S+\\.)+\\S+");
            kv.SetString("flags", "1,9");
            kv.SetString("match", "1");
        }
        kv.Rewind();

        kv.JumpToKey("2", true);
        {
            kv.SetString("pattern", "(?<=\\W|^)(б+л+я+|с+у+к+а*|п+и+з+д+е+ц+)(?=\\W|$)");
            kv.SetString("flags", "1,9");
            kv.SetString("match", "1");
        }
        kv.Rewind();

        kv.ExportToFile(path);
        SetFailState("A new configuration has been generated. Please set up the config file before using");
    }

    if (kv.ImportFromFile(path))
    {
        hPack = new DataPack();
        int flags, offset, res;
        char buffer[REGEX_MAXLEN + 2], error[256];
        kv.GotoFirstSubKey(false);
        do
        {
            flags = offset = 0;
            kv.GetString("flags", sz(buffer));
            do
            {
                switch ((res = StringToInt(buffer[offset])))
                {
                    case FLAG_NONE:
                    {
                    }
                    case FLAG_CASELESS:
                        flags |= PCRE_CASELESS;
                    case FLAG_MULTILINE:
                        flags |= PCRE_MULTILINE;
                    case FLAG_DOTALL:
                        flags |= PCRE_DOTALL;
                    case FLAG_EXTENDED:
                        flags |= PCRE_EXTENDED;
                    case FLAG_ANCHORED:
                        flags |= PCRE_ANCHORED;
                    case FLAG_DOLLAR_ENDONLY:
                        flags |= PCRE_DOLLAR_ENDONLY;
                    case FLAG_UNGREEDY:
                        flags |= PCRE_UNGREEDY;
                    case FLAG_NOTEMPTY:
                        flags |= PCRE_NOTEMPTY;
                    case FLAG_UTF8:
                        flags |= PCRE_UTF8;
                    case FLAG_NO_UTF8_CHECK:
                        flags |= PCRE_NO_UTF8_CHECK;
                    case FLAG_UCP:
                        flags |= PCRE_UCP;
                    default:
                    {
                        kv.GetSectionName(sz(buffer));
                        SetFailState("Flag %d in key %s is not valid", res, buffer);
                    }
                }
            }
            while ((offset = FindCharInString(buffer[offset], FLAGS_DELIMETER) + 1))
            
            kv.GetString("pattern", sz(buffer));
            if (buffer[REGEX_MAXLEN])
            {
                kv.GetSectionName(sz(buffer));
                SetFailState("The pattern under the key %s exceeds the maximum size of "...REGEX_MAXLEN_CON..." bytes", buffer);
            }

#define regex view_as<Regex>(res)
#define regex_err view_as<RegexError>(offset)
            if (!(regex = new Regex(buffer, flags, sz(error), regex_err)))
            {
                kv.GetSectionName(sz(buffer));
                SetFailState("An error occurred while testing the regular expression in key %s: (%d) %s", buffer, regex_err, error);
            }
            hPack.WriteCell(regex);
#undef regex
#undef regex_err

            hPack.WriteCell(kv.GetNum("match"));
            iCount++;
        }
        while (kv.GotoNextKey(false));
    }
    else
    {
        SetFailState("Plugin configuration load error");
    }
    kv.Close();
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    hPack.Position = view_as<DataPackPos>(0);
    int i = -1, res;
    while (++i < iCount)
    {
        res = view_as<Regex>(hPack.ReadCell()).Match(sArgs);
        if (hPack.ReadCell())
        {
            if (0 < res)
                return Plugin_Stop;
        }
        else
        {
            if (!res)
                return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}
