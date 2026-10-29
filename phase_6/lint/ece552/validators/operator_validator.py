from pyslang import (Token, SyntaxNode, UnaryExpression, BinaryExpression,
                     UnaryOperator, BinaryOperator, ExpressionKind,
                     ASTContext, EvalContext, LookupLocation)
from .validator import Validator


# This dict (plus binary_ops below) is what's actually enforced -- it
# should match the "Operator Restrictions" section of the wisc26 site
# repo's site/rules.md (a different repo, not cross-linkable here) point
# for point in both directions. They've drifted before in this exact spot
# (rules.md once documented && / || as banned when this dict had already
# stopped enforcing that) -- if you change one, check the other.
#
# Operators are blacklisted along with a reason
unary_ops = {
    # UnaryOperator.Plus,
    # UnaryOperator.Minus,
    # UnaryOperator.BitwiseNot,
    # UnaryOperator.BitwiseAnd,
    # UnaryOperator.BitwiseOr,
    # UnaryOperator.BitwiseXor,
    # UnaryOperator.BitwiseNand,
    # UnaryOperator.BitwiseNor,
    # UnaryOperator.BitwiseXnor,
    # UnaryOperator.LogicalNot,
    # UnaryOperator.Preincrement,
    # UnaryOperator.Predecrement,
    # UnaryOperator.Postincrement,
# UnaryOperator.Postdecrement,
}

binary_ops = {
    # BinaryOperator.Add,
    # BinaryOperator.Subtract,
    BinaryOperator.Multiply: "multiply operator '*' synthesizes poorly",
    BinaryOperator.Divide: "divide operator '/' synthesizes poorly",
    BinaryOperator.Mod: "modulo operator '%' synthesizes poorly",
    # BinaryOperator.BinaryAnd,
    # BinaryOperator.BinaryOr,
    # BinaryOperator.BinaryXor,
    # BinaryOperator.BinaryXnor,
    # BinaryOperator.Equality,
    # BinaryOperator.Inequality,
    BinaryOperator.CaseEquality: "case equality operator '===' is not synthesizable",
    BinaryOperator.CaseInequality: "case inequality operator '!==' is not synthesizable",
    # BinaryOperator.GreaterThanEqual,
    # BinaryOperator.GreaterThan,
    # BinaryOperator.LessThanEqual,
    # BinaryOperator.LessThan,
    # These could be allowed with further constexpr analysis, but blacklist for now.
    BinaryOperator.WildcardEquality: "wildcard equality operator '==?' may synthesize poorly",
    BinaryOperator.WildcardInequality: "wildcard inequality operator '!=?' may synthesize poorly",
    # BinaryOperator.LogicalAnd,
    # BinaryOperator.LogicalOr,
    # BinaryOperator.LogicalImplication,
    # BinaryOperator.LogicalEquivalence,
    # BinaryOperator.LogicalShiftLeft,
    # BinaryOperator.LogicalShiftRight,
    # BinaryOperator.ArithmeticShiftLeft,
    # BinaryOperator.ArithmeticShiftRight,
    BinaryOperator.Power: "power operator '^' synthesizes poorly",
}


# Operators whose only objection is synthesis cost -- see the reasons in
# binary_ops above, which all say "synthesizes poorly". That objection does not
# apply when the value is computed at elaboration and no hardware is emitted
# for it, so these are permitted in a constant expression. The canonical case
# is slicing a flattened array inside a generate loop, `x[32*k +: 32]`, where
# `k` is a genvar: writing that as a variable multiply is impossible, so
# rejecting it rejected the only reasonable way to express the slice.
#
# `===`, `!==`, `==?` and `!=?` deliberately do NOT get this exemption: those
# are about X and wildcard semantics rather than synthesis cost, so a constant
# one is still expressing something that has no hardware meaning.
constant_foldable_ops = frozenset([
    BinaryOperator.Multiply,
    BinaryOperator.Divide,
    BinaryOperator.Mod,
    BinaryOperator.Power,
])


# Phase 6 has no per-file operator exemptions: `*`, `/` and `%` on signals are
# rejected in every file, including alu.v (RV32M) and fpu.v, so every
# multiplier and divider is built out of adds, shifts and subtracts. (An
# earlier draft exempted muldiv.v and fpu.v; course staff reversed that.)


class OperatorValidator(Validator):
    def _report_invalid(self, expr: UnaryExpression | BinaryExpression, reason: str):
        srcfile = self.source_file(expr.sourceRange.start)
        self.report(
            srcfile=srcfile,
            title="operator not synthesizable or disallowed",
            messages=[(Validator.span(expr.sourceRange), reason)],
            hint="if really needed, please implement operator manually",
        )

    def _is_constant(self, expr) -> bool:
        """True when `expr`'s value is fixed at elaboration.

        `expr.constant` is only populated where slang already had to evaluate
        the expression -- inside an elaborated generate block, for instance --
        so a parameter arithmetic expression in a continuous assignment comes
        back None even though it folds. Evaluating explicitly covers both, and
        yields no value at all for anything that depends on a runtime signal.
        """
        if expr.constant is not None:
            return True
        if self.compilation is None:
            return False
        try:
            context = EvalContext(ASTContext(self.compilation.getRoot(),
                                             LookupLocation.max))
            return expr.eval(context).value is not None
        except Exception:
            return False

    @staticmethod
    def _shift_illegal(expr: BinaryExpression) -> bool:
        shift = expr.op in [
            BinaryOperator.LogicalShiftLeft,
            BinaryOperator.LogicalShiftRight,
            BinaryOperator.ArithmeticShiftLeft,
            BinaryOperator.ArithmeticShiftRight,
        ]

        if shift:
            amount = expr.right
            if amount.kind == ExpressionKind.IntegerLiteral:
                return False
            print(amount.kind)
            if amount.constant is not None:
                return False
            return True
        return False

    def __call__(self, obj: Token | SyntaxNode):
        # Check operators against the blacklist.
        if isinstance(obj, UnaryExpression):
            if obj.op in unary_ops:
                self._report_invalid(obj, unary_ops[obj.op])
        if isinstance(obj, BinaryExpression):
            if obj.op in binary_ops:
                if not (obj.op in constant_foldable_ops and self._is_constant(obj)):
                    self._report_invalid(obj, binary_ops[obj.op])

        # Check that shifts only shift by constant amounts.
        if isinstance(obj, BinaryExpression):
            if OperatorValidator._shift_illegal(obj):
                self._report_invalid(obj, "shift amount is not a constant expression")
