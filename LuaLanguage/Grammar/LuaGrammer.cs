using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Irony.Parsing;

namespace LuaLanguage
{
    [Language("Lua", "5.1", "Lua Script Language")]
    public class LuaGrammar : Irony.Parsing.Grammar
    {
        public LuaGrammar() :
            base(true)
        {
            #region Declare Terminals Here
            StringLiteral STRING = CreateLuaString("string");
            NumberLiteral NUMBER = CreateLuaNumber("number");

            LuaLongStringTerminal LONGSTRING = new LuaLongStringTerminal("long-string");

            // This includes both single-line and block comments
            var Comment = new LuaCommentTerminal("block-comment");
           

            //  Regular Operators
            
            //  Member Select Operators
            var DOT = Operator(".");
            DOT.EditorInfo = new TokenEditorInfo(TokenType.Operator, TokenColor.Text, TokenTriggers.MemberSelect);

            var COLON = Operator(":");
            COLON.EditorInfo = new TokenEditorInfo(TokenType.Operator, TokenColor.Text, TokenTriggers.MemberSelect);

            //  Standard Operators
            var EQ = Operator("=");

            //yujiang: Ignore comment
            NonGrammarTerminals.Add(Comment);

            #region Keywords
            var LOCAL = Keyword("local");
            var DO = Keyword("do");
            var END = Keyword("end");
            var WHILE = Keyword("while");
            var REPEAT = Keyword("repeat");
            var UNTIL = Keyword("until");
            var IF = Keyword("if");
            var THEN = Keyword("then");
            var ELSEIF = Keyword("elseif");
            var ELSE = Keyword("else");
            var FOR = Keyword("for");
            var IN = Keyword("in");
            var FUNCTION = Keyword("function");
            var RETURN = Keyword("return");
            var BREAK = Keyword("break");
            var NIL = Keyword("nil");
            var FALSE = Keyword("false");
            var TRUE = Keyword("true");
            var NOT = Keyword("not");
            var AND = Keyword("and");
            var OR = Keyword("or");
            #endregion
            IdentifierTerminal Name = new IdentifierTerminal("identifier");

             #endregion

            #region Declare NonTerminals Here
            NonTerminal Chunk = new NonTerminal("chunk");
            NonTerminal Block = new NonTerminal("block");

            NonTerminal Statement = new NonTerminal("statement");
            NonTerminal LastStatement = new NonTerminal("last statement");
            NonTerminal FuncName = new NonTerminal("function name");
            NonTerminal VarList = new NonTerminal("var list");
            NonTerminal Var = new NonTerminal("var");
            NonTerminal NameList = new NonTerminal("name list");
            NonTerminal ExprList = new NonTerminal("expr list");
            NonTerminal Expr = new NonTerminal("expr");
            NonTerminal PrefixExpr = new NonTerminal("prefix expr");
            NonTerminal FunctionCall = new NonTerminal("function call");
            NonTerminal Args = new NonTerminal("args");
            NonTerminal NamedFunction = new NonTerminal("named function");
            NonTerminal NamelessFunction = new NonTerminal("nameless function");
            NonTerminal FuncBody = new NonTerminal("function body");
            NonTerminal ParList = new NonTerminal("parlist");
            NonTerminal TableConstructor = new NonTerminal("table constructor");
            NonTerminal FieldList = new NonTerminal("field list");
            NonTerminal Field = new NonTerminal("field");
            NonTerminal FieldSep = new NonTerminal("field seperator");
            NonTerminal BinOp = new NonTerminal("binop");
            NonTerminal UnOp = new NonTerminal("unop");

            
            #endregion

            #region Place Rules Here
            //Using Lua 5.1 grammar as defined in
            //http://www.lua.org/manual/5.1/manual.html#8
            this.Root = Chunk;

            //chunk ::= {stat [`;´]} [laststat [`;´]]
            Chunk.Rule = (Statement + ToTerm(";").Q()).Star() + (LastStatement + ToTerm(";").Q()).Q();
            
            //block ::= chunk
            Block = Chunk;
 
            //stat ::=  varlist `=´ explist | 
            //     functioncall | 
            //     do block end | 
            //     while exp do block end | 
            //     repeat block until exp | 
            //     if exp then block {elseif exp then block} [else block] end | 
            //     for Name `=´ exp `,´ exp [`,´ exp] do block end | 
            //     for namelist in explist do block end | 
            //     function funcname funcbody | 
            //     local function Name funcbody | 
            //     local namelist [`=´ explist] 
            Statement.Rule = VarList + "=" + ExprList |
                            FunctionCall |
                            DO + Block + END |
                            WHILE + Expr + DO + Block + END |
                            REPEAT + Block + UNTIL + Expr |
                            IF + Expr + THEN + Block + (ELSEIF + Expr + THEN + Block).Star() + (ELSE + Block).Q() + END |
                            FOR + Name + "=" + Expr + "," + Expr + ("," + Expr).Q() + DO + Block + END |
                            FOR + NameList + IN + ExprList + DO + Block + END |
                            NamedFunction |
                            LOCAL + NamedFunction |
                            LOCAL + NameList + ("=" + ExprList).Q();

            //laststat ::= return [explist] | break
            LastStatement.Rule = RETURN + ExprList.Q() | BREAK;

            //funcname ::= Name {`.´ Name} [`:´ Name]
            FuncName.Rule = Name + (DOT + Name).Star() + (COLON + Name).Q();

            //NamedFunction = 'function' + FuncName + FuncBody
            NamedFunction.Rule = FUNCTION + FuncName + FuncBody;

            //varlist ::= var {`,´ var}
            VarList.Rule = MakePlusRule(VarList, ToTerm(","), Var);

            //namelist ::= Name {`,´ Name}
            NameList.Rule = MakePlusRule(NameList, ToTerm(","), Name);

            //explist ::= {exp `,´} exp
            ExprList.Rule = MakePlusRule(ExprList, ToTerm(","), Expr);

            //exp ::=  nil | false | true | Number | String | `...´ | function | 
            //     prefixexp | tableconstructor | exp binop exp | unop exp 
            Expr.Rule = NIL | FALSE | TRUE | NUMBER | STRING | LONGSTRING | "..." | NamelessFunction |
                PrefixExpr | TableConstructor | Expr + BinOp + Expr | UnOp + Expr;

            //var ::=  Name | prefixexp `[´ exp `]´ | prefixexp `.´ Name 
            Var.Rule = Name | PrefixExpr + "[" + Expr + "]" | PrefixExpr + DOT + Name;

            //prefixexp ::= var | functioncall | `(´ exp `)´
            PrefixExpr.Rule = Var | FunctionCall | "(" + Expr + ")";

            //functioncall ::=  prefixexp args | prefixexp `:´ Name args 
            FunctionCall.Rule = PrefixExpr + Args | PrefixExpr + COLON + Name + Args;

            //args ::=  `(´ [explist] `)´ | tableconstructor | String 
            Args.Rule = "(" + ExprList.Q() + ")" | TableConstructor | STRING | LONGSTRING;

            //function ::= function funcbody
            NamelessFunction.Rule = FUNCTION + FuncBody;

            //funcbody ::= `(´ [parlist] `)´ block end
            FuncBody.Rule = "(" + ParList.Q() + ")" + Block + END;

            //parlist ::= namelist [`,´ `...´] | `...´
            ParList.Rule = NameList + (ToTerm(",") + "...").Q() | "...";

            //tableconstructor ::= `{´ [fieldlist] `}´
            TableConstructor.Rule = "{" + FieldList.Q() + "}";

            //fieldlist ::= field {fieldsep field} [fieldsep]
            FieldList.Rule = Field + (FieldSep + Field).Star() + FieldSep.Q();
          
            //field ::= `[´ exp `]´ `=´ exp | Name `=´ exp | exp
            Field.Rule = "[" + Expr + "]" + "=" + Expr | Name + "=" + Expr | Expr; 

            //fieldsep ::= `,´ | `;´
            FieldSep.Rule = ToTerm(",") | ";";

            //binop ::= `+´ | `-´ | `*´ | `/´ | `^´ | `%´ | `..´ | 
            //     `<´ | `<=´ | `>´ | `>=´ | `==´ | `~=´ | 
            //     and | or
            BinOp.Rule = ToTerm("+") | "-" | "*" | "/" | "^" | "%" | ".." |
                    "<" | "<=" | ">" | ">=" | "==" | "~=" |
                    AND | OR;

            //unop ::= `-´ | not | `#´
            UnOp.Rule = ToTerm("-") | NOT | "#";



            #endregion

            #region Define Keywords and Register Symbols
            this.RegisterBracePair("(", ")");
            this.RegisterBracePair("{", "}");
            this.RegisterBracePair("[", "]");

            this.MarkPunctuation(",", ";");
           
            this.RegisterOperators(1, OR);
            this.RegisterOperators(2, AND);
            this.RegisterOperators(3, "<",">","<=",">=","~=","==");
            this.RegisterOperators(4, Associativity.Right, "..");
            this.RegisterOperators(5, "+", "-");
            this.RegisterOperators(6, "*", "/", "%");
            this.RegisterOperators(7, NOT); //also -(unary)
            this.RegisterOperators(8, Associativity.Right, "^");

            #endregion

            //yujiang: register lua functions
            //this.LuaRegisterFunctions();
        }

        //public KeyTerm BaseFunction(string keyword)
        //{
        //    var term = ToTerm(keyword);
        //    // term.SetOption(TermOptions.IsKeyword, true);
        //    // term.SetOption(TermOptions.IsReservedWord, true);

        //    this.MarkReservedWords(keyword);
        //    term.EditorInfo = new TokenEditorInfo(TokenType.Keyword, TokenColor.Comment, TokenTriggers.None);

        //    return term;
        //}

        //public void LuaRegisterFunctions()
        //{
        //    string[] funcs = { "_VERSION", "assert", "collectgarbage", "dofile", "error", "getfenv", "getmetatable", 
        //                         "ipairs", "load", "loadfile", "loadstring", "module", "next", "pairs", "pcall", "print", 
        //                         "rawequal", "rawget", "rawset", "require", "select", "setfenv", "setmetatable", 
        //                         "tonumber", "tostring", "type", "unpack", "xpcall", };
        //    string[] tables = { "_G", "coroutine", "io", "file", "math", "debug", "string", "package", "table", };
        //    foreach (string str in funcs)
        //    {
        //        BaseFunction(str);
        //    }
        //    foreach (string str in tables)
        //    {
        //        BaseFunction(str);
        //    }
        //}

        //Must create new overrides here in order to support the "Operator" token color
        public new void RegisterOperators(int precedence, params string[] opSymbols) 
        {
            RegisterOperators(precedence, Associativity.Left, opSymbols);
        }

        //Must create new overrides here in order to support the "Operator" token color
        public new void RegisterOperators(int precedence, Associativity associativity, params string[] opSymbols) 
        {
            foreach (string op in opSymbols)
            {
                KeyTerm opSymbol = Operator(op);
                opSymbol.Precedence = precedence;
                opSymbol.Associativity = associativity;
            }
        }

        public KeyTerm Keyword(string keyword)
        {
            var term = ToTerm(keyword);
           // term.SetOption(TermOptions.IsKeyword, true);
           // term.SetOption(TermOptions.IsReservedWord, true);

            this.MarkReservedWords(keyword);
            term.EditorInfo = new TokenEditorInfo(TokenType.Keyword, TokenColor.Keyword, TokenTriggers.None);

            return term;
        }

        public KeyTerm Operator(string op)
        {
            string opCased = this.CaseSensitive ? op : op.ToLower();
            var term = new KeyTerm(opCased, op);
            //term.SetOption(TermOptions.IsOperator, true);
            
            //term.EditorInfo = new TokenEditorInfo(TokenType.Operator, TokenColor.Operator, TokenTriggers.None);

            return term;
        }

        protected static NumberLiteral CreateLuaNumber(string name)
        {
            NumberLiteral term = new NumberLiteral(name, NumberOptions.AllowStartEndDot);
            //default int types are Integer (32bit) -> LongInteger (BigInt); Try Int64 before BigInt: Better performance?
            term.DefaultIntTypes = new TypeCode[] { TypeCode.Int32, TypeCode.Int64, NumberLiteral.TypeCodeBigInt };
            term.DefaultFloatType = TypeCode.Double; // it is default
            term.AddPrefix("0x", NumberOptions.Hex);
            
            return term;
        }

        protected static StringLiteral CreateLuaString(string name)
        {
            return new LuaStringLiteral(name);
        }
    }
}
