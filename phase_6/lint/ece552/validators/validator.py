import sys
from typing import Optional
from pyslang import SourceManager, SourceRange, SourceLocation, Token, SyntaxNode
from prettyerr import SrcFile, Span, Error, PointerMessage


class Validator:
    def __init__(self, source_manager: SourceManager, compilation=None):
        self.source_manager = source_manager
        # The compilation is needed to build an EvalContext, which is how a
        # validator asks "is this expression's value known at elaboration?".
        # Optional so a validator can still be constructed standalone (in a
        # test, say); a validator that needs it degrades gracefully without.
        self.compilation = compilation
        self.errors: list[Error] = []

    @staticmethod
    def span(source_range: SourceRange) -> Span:
        start = source_range.start
        end = source_range.end
        return Span(start.offset, end.offset)

    def source_file(self, location: SourceLocation) -> SrcFile:
        text = self.source_manager.getSourceText(location.buffer)
        filename = self.source_manager.getFileName(location)
        return SrcFile.from_text(text, filename)

    def report(self, srcfile: SrcFile, title: str, messages: list[tuple[Span, str]], hint: Optional[str] = None):
        err = Error(
            srcfile,
            title=title,
            pointer_messages=[PointerMessage(span=span, message=message) for span, message in messages],
            hint=hint,
        )
        self.errors.append(err)

    def __call__(self, obj: Token | SyntaxNode):
        pass
