from pyslang import *
from .validator import Validator


simulation_statements = [
    # BlockStatement,
    BreakStatement,
    # CaseStatement,
    # ConcurrentAssertionStatement,
    # ConditionalStatement,
    ContinueStatement,
    DisableForkStatement,
    DisableStatement,
    DoWhileLoopStatement,
    # EmptyStatement,
    EventTriggerStatement,
    # ExpressionStatement,
    # ForLoopStatement -- handled separately in __call__ below. A for loop
    # whose trip count is fixed at elaboration unrolls into straight-line
    # logic and synthesizes fine (clearing a register array on reset is the
    # canonical case), so blanket-rejecting every for loop rejected correct,
    # synthesizable code. Only unbounded or data-dependent loops are
    # rejected now; see BehavioralValidator._loop_is_bounded().
    # ForeachLoopStatement,
    # ForeverLoopStatement,
    ImmediateAssertionStatement,
    # InvalidStatement,
    # PatternCaseStatement,
    # ProceduralAssignStatement,
    ProceduralCheckerStatement,
    ProceduralDeassignStatement,
    RandCaseStatement,
    RandSequenceStatement,
    RepeatLoopStatement,
    ReturnStatement,
    # StatementList,
    # TimedStatement,
    # VariableDeclStatement,
    WaitForkStatement,
    WaitOrderStatement,
    WaitStatement,
    WhileLoopStatement,
]

simulation_expressions = [
    # ArbitrarySymbolExpression,
    AssertionInstanceExpression,
    # AssignmentExpression,
    AssignmentPatternExpressionBase, # TODO: what is this
    # BinaryExpression,
    # CallExpression,
    ClockingEventExpression,
    # ConcatenationExpression,
    # ConditionalExpression,
    # ConversionExpression,
    CopyClassExpression,
    # DataTypeExpression,
    DistExpression,
    # ElementSelectExpression,
    # EmptyArgumentExpression,
    InsideExpression,
    # IntegerLiteral,
    InvalidExpression,
    # LValueReferenceExpression,
    # MemberAccessExpression,
    MinTypMaxExpression,
    # NewArrayExpression,
    # NewClassExpression,
    NewCovergroupExpression,
    NullLiteral,
    # RangeSelectExpression,
    RealLiteral,
    # ReplicationExpression,
    # StreamingConcatenationExpression,
    StringLiteral,
    # TaggedUnionExpression,
    TimeLiteral,
    TypeReferenceExpression,
    # UnaryExpression,
    # UnbasedUnsizedIntegerLiteral,
    UnboundedLiteral,
    # ValueExpressionBase,
    ValueRangeExpression
]

constonly_expressions = [
    ArbitrarySymbolExpression,
    AssertionInstanceExpression,
    AssignmentExpression,
    AssignmentPatternExpressionBase,
    BinaryExpression,
    CallExpression,
    ClockingEventExpression,
    ConcatenationExpression,
    ConditionalExpression,
    ConversionExpression,
    CopyClassExpression,
    DataTypeExpression,
    DistExpression,
    ElementSelectExpression,
    EmptyArgumentExpression,
    InsideExpression,
    IntegerLiteral,
    InvalidExpression,
    LValueReferenceExpression,
    MemberAccessExpression,
    MinTypMaxExpression,
    NewArrayExpression,
    NewClassExpression,
    NewCovergroupExpression,
    NullLiteral,
    RangeSelectExpression,
    RealLiteral,
    ReplicationExpression,
    StreamingConcatenationExpression,
    StringLiteral,
    TaggedUnionExpression,
    TimeLiteral,
    TypeReferenceExpression,
    UnaryExpression,
    UnbasedUnsizedIntegerLiteral,
    UnboundedLiteral,
    ValueExpressionBase,
    ValueRangeExpression
]

timing_controls = [
    BlockEventListControl,
    CycleDelayControl,
    Delay3Control,
    DelayControl,
    # EventListControl,
    # ImplicitEventControl,
    InvalidTimingControl,
    OneStepDelayControl,
    RepeatedEventControl,
    # SignalEventControl
]


# Symbols whose value is fixed at elaboration time. A `for` loop whose bounds
# reference only these -- plus its own loop variables -- has a trip count known
# at compile time, so it unrolls.
constant_symbol_kinds = frozenset([
    SymbolKind.Parameter,
    SymbolKind.Specparam,
    SymbolKind.Genvar,
    SymbolKind.EnumValue,
])


class BehavioralValidator(Validator):
    def __init__(self, source_manager: SourceManager, compilation=None):
        super().__init__(source_manager, compilation)
        self.timing = None

    def _validate_timing(self, timing: TimingControl):
        srcfile = self.source_file(timing.sourceRange.start)
        if any(isinstance(timing, T) for T in timing_controls):
            self.report(
                srcfile=srcfile,
                title="illegal or simulation only timing control",
                messages=[(Validator.span(timing.sourceRange), "timing control (event or delay) intended for simulation only or is disallowed")],
            )

        # Recursively check event lists.
        if isinstance(timing, EventListControl):
            for event in timing.events:
                self._validate_timing(event)

        # Only some types of events are allowed.
        if isinstance(timing, SignalEventControl):
            ok = True
            ok = ok and (timing.iffCondition is None)
            ok = ok and (timing.edge == EdgeKind.None_ or timing.edge == EdgeKind.PosEdge)
            if not ok:
                self.report(
                    srcfile=srcfile,
                    title="illegal or simulation only timing control",
                    messages=[(Validator.span(timing.sourceRange), "disallowed signal event")],
                )

    @staticmethod
    def _loop_variables(stmt: ForLoopStatement) -> set:
        """Names the loop declares or initializes: both `for (integer i = 0; ...)`
        and `for (i = 0; ...)` against a variable declared outside."""
        names = set()
        for var in stmt.loopVars:
            if getattr(var, "name", None):
                names.add(var.name)
        for init in stmt.initializers:
            symbol = getattr(getattr(init, "left", None), "symbol", None)
            if getattr(symbol, "name", None):
                names.add(symbol.name)
        return names

    @staticmethod
    def _runtime_refs(expr, loop_vars: set) -> list:
        """Names in `expr` that are neither loop variables nor elaboration-time
        constants -- exactly the things that would make a trip count depend on a
        runtime value."""
        found = []

        def collect(node):
            if isinstance(node, ValueExpressionBase):
                symbol = getattr(node, "symbol", None)
                name = getattr(symbol, "name", None)
                if (name is not None
                        and name not in loop_vars
                        and getattr(symbol, "kind", None) not in constant_symbol_kinds
                        and node.constant is None):
                    found.append(name)

        expr.visit(collect)
        return found

    @classmethod
    def _loop_is_bounded(cls, stmt: ForLoopStatement):
        """(bounded, reason). Bounded means the trip count is fixed at
        elaboration: the loop variables start at constants, and the stop and
        step expressions reference nothing but those variables and constants."""
        loop_vars = cls._loop_variables(stmt)
        if not loop_vars:
            return False, "it has no loop variable"
        if stmt.stopExpr is None:
            return False, "it has no stop condition, so it never terminates"
        for init in stmt.initializers:
            right = getattr(init, "right", None)
            if right is None or right.constant is None:
                return False, "its loop variable is not initialized to a constant"
        checks = [(stmt.stopExpr, "stop condition")]
        checks += [(step, "step expression") for step in stmt.steps]
        for expr, where in checks:
            refs = cls._runtime_refs(expr, loop_vars)
            if refs:
                return False, ("its %s depends on %s, which is not known at "
                               "compile time" % (where, ", ".join(sorted(set(refs)))))
        return True, ""

    def __call__(self, obj: Token | SyntaxNode):
        # Check for disallowed statements, expressions, and simulation/verification constructs.
        if any(isinstance(obj, S) for S in simulation_statements):
            srcfile = self.source_file(obj.sourceRange.start)
            self.report(
                srcfile=srcfile,
                title="use of simulation only construct",
                messages=[(Validator.span(obj.sourceRange), "construct intended for simulation only and does not synthesize well")],
            )

        # A for loop is allowed when its trip count is fixed at elaboration --
        # it unrolls into straight-line logic. One whose bounds depend on a
        # runtime value does not unroll and is rejected.
        if isinstance(obj, ForLoopStatement):
            bounded, reason = self._loop_is_bounded(obj)
            if not bounded:
                self.report(
                    srcfile=self.source_file(obj.sourceRange.start),
                    title="for loop is not bounded at compile time",
                    messages=[(Validator.span(obj.sourceRange),
                               "a for loop must unroll, but %s" % reason)],
                    hint="give the loop constant bounds, or write the logic out explicitly",
                )

        if any(isinstance(obj, S) for S in simulation_expressions):
            srcfile = self.source_file(obj.sourceRange.start)
            self.report(
                srcfile=srcfile,
                title="use of simulation only construct",
                messages=[(Validator.span(obj.sourceRange), "construct intended for simulation only and does not synthesize well")],
            )

        # Verify behavioral timing control. This course requires a single
        # clock signal in the sensitivity list (synchronous reset via
        # `if (i_rst) ... else ...` inside the clocked block, not a second
        # signal like `always @(posedge clk or posedge rst)`) -- that's
        # always been the rule, this validator just used to enforce it by
        # crashing. `EventListControl` (multiple signals) used to fall into
        # an `assert isinstance(obj.timing, ImplicitEventControl)` that
        # doesn't match it, raising an unhandled AssertionError -- a Python
        # traceback shown to the student as their compile error, not an
        # actual rule violation message. Same real outcome (rejected),
        # cleaner reporting.
        #
        # Separately, a SignalEventControl (single signal) whose expr is a
        # MemberAccessExpression rather than a bare NamedValueExpression
        # (e.g. `always @(posedge a.b)`) hit the same assert even though
        # it's still exactly one signal -- that shape is fine and is
        # handled generically below via `.syntax` instead of assuming a
        # specific expression type.
        if isinstance(obj, TimedStatement):
            self._validate_timing(obj.timing)

            if isinstance(obj.timing, ImplicitEventControl):
                self.timing = None
            elif isinstance(obj.timing, SignalEventControl):
                self.timing = str(obj.timing.expr.syntax).strip()
            elif isinstance(obj.timing, EventListControl):
                self.report(
                    srcfile=self.source_file(obj.timing.sourceRange.start),
                    title="multiple signals in sensitivity list",
                    messages=[(Validator.span(obj.timing.sourceRange),
                               "only a single clock signal is allowed here -- "
                               "use `if (i_rst) ... else ...` inside this "
                               "clocked block for synchronous reset instead "
                               "of a second signal")],
                )
                self.timing = str(obj.timing.syntax).strip()
            else:
                self.timing = str(obj.timing.syntax).strip()

        # Verify conditional statements. rf.v is exempt: the course's own
        # spec (project2.md, "Problem 2: Register File") explicitly says
        # "You may also use behavioral if/else Verilog for this problem
        # only" for the register-file bypass mux, which is combinational
        # (o_rs1_rdata/o_rs2_rdata aren't registered outputs). rf.v is a
        # fixed, required filename reused unmodified across every later
        # project (3-7 all carry the same rf.v forward, just with
        # BYPASS_EN=0), so the exemption follows the file, not the project
        # number -- the same submitted rf.v shouldn't pass validate in one
        # project and fail in the next. Every other file and every other
        # rule is unaffected.
        if isinstance(obj, ConditionalStatement):
            srcfile = self.source_file(obj.sourceRange.start)
            if self.timing is None and (srcfile.path is None or srcfile.path.name != "rf.v"):
                self.report(
                    srcfile=srcfile,
                    title="if/else statement not allowed in combinational logic",
                    messages=[(Validator.span(obj.sourceRange), "conditional statements (if/else) are only allowed for inferring registers in clocked blocks")],
                )

        # Verify blocks are sequential.
        if isinstance(obj, BlockStatement):
            ok = True
            ok = ok and obj.blockKind == StatementBlockKind.Sequential
            if not ok:
                self.report(
                    srcfile=self.source_file(obj.sourceRange.start),
                    title="illegal block kind",
                    messages=[(Validator.span(obj.sourceRange), "only sequential blocks are allowed, parallel (e.g. join) block detected")],
                )

        # Verify calls are only made to constexpr values.
        if isinstance(obj, CallExpression):
            if obj.constant is None:
                self.report(
                    srcfile=self.source_file(obj.sourceRange.start),
                    title="illegal call expression",
                    messages=[(Validator.span(obj.sourceRange), "functions calls are only allowed for constant expressions (like $clog2). $display, etc are unsynthesizable.")],
                )

        # Check that if/else statements are complete. Switch defaults are detected by
        # slang's builtin warnings.
        # if isinstance(obj, ConditionalStatement):
        #     if obj.ifFalse is None:
        #         self.report(
        #             srcfile=
        #         )
