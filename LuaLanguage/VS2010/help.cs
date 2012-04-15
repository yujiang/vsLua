using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

namespace LuaLanguage
{
    public class TableFunction
    {
        public TableFunction(string l)
        {
            line = l;
            int i = line.IndexOf('.');
            int j = line.IndexOf(':');
            if (i == -1)
                i = j;
            else if(j == -1)
                j = i;
            if (i > j)
                i = j;

            table = i;
            param = line.IndexOf('(',i+1);
            if (param != -1)
            {
                //MR.get_option(m,func,_index) --得到选项
                comment = line.IndexOf(')', param + 1);
                if (comment == -1)
                    param = -1;
                else
                    comment += 1;
            }
            else
            {
                //MU.MONEY_YILIANG = 1 --银两
                comment = line.IndexOf('=');
                //if (comment != -1)
                  //  comment = comment - 1;
            }
        }
        public bool is_const_var()
        {
            return param == -1 && comment != -1;
        }

        public string line;
        public string GetTable()
        {
            if (table < 0)
                return "_G";
            return line.Substring(0, table);
        }
        public char GetDot()
        {
            if (table < 0)
                return '.';
            return line[table];
        }
--        //int next;
        --
        public string GetTableNext()
        {
            if (table < 0)
                return line;
            return line.Substring(table + 1);
        }
        int table;
        public string GetFunction()
        {
            int start = table + 1;
            if (param == -1)
                return line.Substring(start);
            return line.Substring(start, param - start);
        }
        int param;
        public string GetParam()
        {
            if (param == -1)
                return "";
            return line.Substring(param, comment - param);
        }
        public string GetFunctionParam()
        {
            int start = table + 1;
            if (comment == -1)
                return line.Substring(start);
            return line.Substring(start, comment - start);
        }
        int comment;
        public string GetComment()
        {
            if (comment == -1)
                return "";
            return line.Substring(comment);
        }
    };

    public sealed class Help
    {
        HashSet<string> _funcions;
        HashSet<string> _tables;
        HashSet<string> _classes;
        Dictionary<string,int> _identifiers;

        Dictionary<string, List<TableFunction>> _luaTableFunctionOri;
        
        static Help s_help = null;

        public static Help Instance
        {
            get
            {
                if (s_help == null)
                    s_help = new Help();
                return s_help;
            }
        }

        public Help()
        {
            _luaTableFunctionOri = new Dictionary<string, List<TableFunction>>();
            //_luaTableFunction["_G"] = new List<string>() { "assert", "collectgarbage", "dofile", "error", "getfenv", "getmetatable", "ipairs", "load", "loadfile", "loadstring", "module", "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall", };
            //_luaTableFunction["coroutine"] = new List<string>() { "create", "resume", "running", "status", "wrap", "yield", };
            //_luaTableFunction["debug"] = new List<string>() { "debug", "getfenv", "gethook", "getinfo", "getlocal", "getmetatable", "getregistry", "getupvalue", "setfenv", "sethook", "setlocal", "setmetatable", "setupvalue", "traceback", };
            //_luaTableFunction["io"] = new List<string>() { "close", "flush", "input", "lines", "open", "output", "popen", "read", "stderr", "stdin", "stdout", "tmpfile", "type", "write", };
            //_luaTableFunction["math"] = new List<string>() { "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "cosh", "deg", "exp", "floor", "fmod", "frexp", "huge", "ldexp", "log", "log10", "max", "min", "modf", "pi", "pow", "rad", "random", "randomseed", "sin", "sinh", "sqrt", "tan", "tanh", };
            //_luaTableFunction["os"] = new List<string>() { "clock", "date", "difftime", "execute", "exit", "getenv", "remove", "rename", "setlocale", "time", "tmpname", };
            //_luaTableFunction["package"] = new List<string>() { "cpath", "loaded", "loaders", "loadlib", "path", "preload", "seeall", };
            //_luaTableFunction["string"] = new List<string>() { "byte", "char", "dump", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper", };
            //_luaTableFunction["table"] = new List<string>() { "concat", "sort", "maxn", "remove", "insert", };

            add_dict_by_file(_luaTableFunctionOri, "keyword.lua");
            add_dict_by_file(_luaTableFunctionOri, "my_keyword.lua");

            _funcions = new HashSet<string>();
            _tables = new HashSet<string>();
            _classes = new HashSet<string>();
            _identifiers = new Dictionary<string, int>();

            foreach (var pair in _luaTableFunctionOri)
            {
                var k = pair.Key;
                var v = pair.Value;
                bool have_maohao = false;
                foreach (var tf in v)
                {
                    _funcions.Add(tf.GetFunction());
                    if (tf.GetDot() == ':')
                        have_maohao = true;
                }
                if (!have_maohao)
                    _tables.Add(k);
                else
                    _classes.Add(k);
            }
        }

        public string TryMatchClass(string word)
        {
            if (_classes.Contains(word))
                return word;
            foreach (var s in _classes)
            {
                if (word.StartsWith(s))
                    return s;
            }
            return word;
        }

        public bool TryGetTableFuncs(string word, char dot, out List<TableFunction> l)
        {
            if (dot == ':')
                word = TryMatchClass(word);

            l = new List<TableFunction>();
            List<TableFunction> l2;
            if (_luaTableFunctionOri.TryGetValue(word, out l2))
            {
                foreach (var tf in l2)
                {
                    if (tf.GetDot() == dot)
                        l.Add(tf);
                }
                return true;
            }
            return false;
        }
        public string GetTableFunctionComment(string table,string func)
        {
            if (_luaTableFunctionOri.ContainsKey(table))
            {
                var t = _luaTableFunctionOri[table];
                foreach (var tf in t)
                {
                    if (tf.GetFunction() == func)
                    {
                        return tf.GetTableNext();
                    }
                }
            }
            return "";
        }
        public bool TryGetIdentifiers(string word, out List<string> l)
        {
            l = new List<string>();
            foreach (var pair in _identifiers)
            {
                if (pair.Key != word && pair.Key.StartsWith(word))
                {
                    l.Add(pair.Key);
                }
            }
            
            return l.Count > 0;
        }

        public void AddIdentifier(string word)
        {
            if (_identifiers.ContainsKey(word))
                _identifiers[word] = _identifiers[word] + 1;
            else
            {
                foreach (var pair in _identifiers)
                {
                    if (pair.Key.StartsWith(word))
                        return;
                }
                _identifiers.Add(word, 1);

                var l = new List<string>();
                foreach (var pair in _identifiers)
                {
                    if (word != pair.Key && word.StartsWith(pair.Key))
                        l.Add(pair.Key);
                }
                foreach (var s in l)
                {
                    _identifiers.Remove(s);
                }
            }
        }

        public bool ContainFunction(string word)
        {
            return _funcions.Contains(word);
        }
        public bool ContainTable(string word)
        {
            return _tables.Contains(word);
        }

        public static bool is_word_char(char c)
        {
            return c == '_' || char.IsLetterOrDigit(c);
        }

        static void add_dict_by_file(Dictionary<string, List<TableFunction>> dict, string file)
        {
            string path = @"c:\lib\lua\";
            string pathfile = path + file;
            try
            {
                using (StreamReader r = new StreamReader(pathfile))
                {
                    string line;
                    while ((line = r.ReadLine()) != null)
                    {
                        line.Trim();
                        if (line.Length < 2)
                            continue;
                        if (line.StartsWith("--")) //comment
                            continue;

                        TableFunction tf = new TableFunction(line);
                        var table = tf.GetTable();
                        if (!dict.ContainsKey(table))
                            dict[table] = new List<TableFunction>();
                        dict[table].Add(tf);
                    }
                }
            }
            catch (Exception e)
            {
                // Let the user know what went wrong.
                Console.WriteLine("The file could not be read:");
                Console.WriteLine(e.Message);
            }
        }

    }
}
