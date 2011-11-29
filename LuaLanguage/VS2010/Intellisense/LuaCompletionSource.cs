using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.VisualStudio.Language.Intellisense;
using System.Collections.ObjectModel;
using Microsoft.VisualStudio.Text;
using Microsoft.VisualStudio.Text.Tagging;
using System.ComponentModel.Composition;
using Microsoft.VisualStudio.Utilities;

namespace LuaLanguage
{
    [Export(typeof(ICompletionSourceProvider))]
    [ContentType("Lua")]
    [Name("LuaCompletion")]
    class LuaCompletionSourceProvider : ICompletionSourceProvider
    {
        public ICompletionSource TryCreateCompletionSource(ITextBuffer textBuffer)
        {
            return new LuaCompletionSource(textBuffer);
        }
    }

    class LuaCompletionSource : ICompletionSource
    {
        private ITextBuffer _buffer;
        private bool _disposed = false;

        //each table functions

        public LuaCompletionSource(ITextBuffer buffer)
        {
            _buffer = buffer;         
        }

        public void AugmentCompletionSession(ICompletionSession session, IList<CompletionSet> completionSets)
        {
            if (_disposed)
                throw new ObjectDisposedException("LuaCompletionSource");
         
            ITextSnapshot snapshot = _buffer.CurrentSnapshot;
            var triggerPoint = (SnapshotPoint)session.GetTriggerPoint(snapshot);

            if (triggerPoint == null)
                return;

            var line = triggerPoint.GetContainingLine();
            SnapshotPoint start = triggerPoint;

            var word = start;
            word -= 1;
            var ch = word.GetChar();

            List<Completion> completions = new List<Completion>();

            if (ch == '.' || ch == ':' || ch == '_') //for table search
            {
                while (word > line.Start && Help.is_word_char((word - 1).GetChar()))
                {
                    word -= 1;
                }
                String w = snapshot.GetText(word.Position,start - 1 - word);
                if (ch == '_')
                {
                    if (!FillWord(w,completions))
                        return;
                }
                else
                {
                    if (!FillTable(w,ch,completions))
                        return;
                }
            }
            else
                return;
            if (ch == '_')
            {
                while (start > line.Start && !char.IsWhiteSpace((start - 1).GetChar()))
                {
                    start -= 1;
                }
            }
            var applicableTo = snapshot.CreateTrackingSpan(new SnapshotSpan(start, triggerPoint), SpanTrackingMode.EdgeInclusive);
            var cs = new CompletionSet("All", "All", applicableTo, completions, null);
            completionSets.Add(cs);
            //session.SelectedCompletionSet = cs;
        }

        public bool FillWord(String word, List<Completion> completions)
        {
            List<string> l;
            if (Help.Instance.TryGetIdentifiers(word, out l))
            {
                foreach (var tf in l)
                {
                    //completions.Add(new Completion(tf.GetTableNext(),tf.GetFunction(),null,null,null));
                    completions.Add(new Completion(tf));
                }
                return true;
            }
            return false;
        }

        public bool FillTable(String word, char dot, List<Completion> completions)
        {
            List<TableFunction> l;
            if (Help.Instance.TryGetTableFuncs(word,dot,out l))
            {
                foreach (var tf in l)
                {
                    //completions.Add(new Completion(tf.GetTableNext(),tf.GetFunction(),null,null,null));
                    completions.Add(new Completion(tf.GetTableNext()));
                }
                return true;
            }
            return false;
        }

        public void Dispose()
        {
            _disposed = true;
        }
    }
}

