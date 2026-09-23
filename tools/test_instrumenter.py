#!/usr/bin/env python3
"""
Self-test for the coverage instrumenter.

A coverage number is only as trustworthy as the thing that produced it, so
these pin down which lines the instrumenter treats as executable statements --
particularly the cases where inserting a call would be a syntax error
(`else:`, match patterns, continuation lines, annotations).

Run: python3 tools/test_instrumenter.py
"""
import os
import sys
import textwrap
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from coverage import Instrumenter, strip_comment  # noqa: E402


def instrument(source):
    source = textwrap.dedent(source).replace("    ", "\t").strip("\n")
    inst = Instrumenter(0, source)
    return inst.run(), inst.covered, inst.declarations


class StripCommentTests(unittest.TestCase):
    def test_removes_trailing_comment(self):
        self.assertEqual(strip_comment("var x = 1  # set x").strip(), "var x = 1")

    def test_keeps_hash_inside_a_string(self):
        self.assertEqual(strip_comment('var s = "#notacomment"').strip(), 'var s = "#notacomment"')

    def test_handles_escaped_quotes(self):
        self.assertEqual(strip_comment(r'var s = "a\"b" # c').strip(), r'var s = "a\"b"')


class InstrumenterTests(unittest.TestCase):
    def assert_covered(self, source, expected):
        _out, covered, _declarations = instrument(source)
        self.assertEqual(covered, expected)

    def test_instruments_each_statement_in_a_function(self):
        self.assert_covered("""
            func f():
                var a = 1
                var b = 2
                return a + b
        """, [2, 3, 4])

    def test_skips_blank_lines_and_comments(self):
        self.assert_covered("""
            func f():
                # a comment
                var a = 1

                return a
        """, [3, 5])

    def test_skips_class_level_declarations(self):
        _out, covered, declarations = instrument("""
            extends Node
            const X := 1
            var y := 2
            signal done()

            func f():
                return y
        """)
        self.assertEqual(covered, [7], "only the function body is instrumented")
        self.assertEqual(declarations, 2, "const and var are counted as excluded declarations")

    def test_records_if_elif_else_branches(self):
        # `elif`/`else` cannot take a statement before them, so they are
        # recorded from inside their own block -- but they must still be
        # counted, or branch misses would be invisible.
        self.assert_covered("""
            func f(x):
                if x == 1:
                    return "a"
                elif x == 2:
                    return "b"
                else:
                    return "c"
        """, [2, 3, 4, 5, 6, 7])

    def test_records_each_match_arm(self):
        self.assert_covered("""
            func f(x):
                match x:
                    1:
                        return "one"
                    _:
                        return "other"
        """, [2, 3, 4, 5, 6])

    def test_ignores_continuation_lines_of_a_multiline_call(self):
        self.assert_covered("""
            func f():
                var a = some_call(
                    1,
                    2,
                )
                return a
        """, [2, 6])

    def test_ignores_continuation_lines_of_a_literal(self):
        self.assert_covered("""
            func f():
                var a = [
                    1,
                    2,
                ]
                var b = {
                    "k": "v",
                }
                return [a, b]
        """, [2, 6, 9])

    def test_ignores_backslash_continuations(self):
        self.assert_covered("""
            func f():
                var a = 1 + \\
                    2
                return a
        """, [2, 4])

    def test_ignores_lines_inside_a_block_string(self):
        self.assert_covered('''
            func f():
                var doc = """
                    var fake = 1
                    if fake:
                """
                return doc
        ''', [2, 6])

    def test_does_not_split_an_annotation_from_its_statement(self):
        # Inserting between @warning_ignore and the statement it annotates
        # would move the annotation onto the tracker call.
        out, covered, _declarations = instrument("""
            func f():
                @warning_ignore("redundant_await")
                var a = await g()
                return a
        """)
        self.assertEqual(covered, [2, 4])
        lines = out.split("\n")
        annotation_index = next(i for i, l in enumerate(lines) if "@warning_ignore" in l)
        self.assertIn("var a = await g()", lines[annotation_index + 1],
                      "the annotation still immediately precedes its statement")

    def test_instruments_a_lambda_body(self):
        self.assert_covered("""
            func f():
                var cb = func():
                    return 1
                return cb
        """, [2, 3, 4])

    def test_handles_nested_functions_after_one_another(self):
        self.assert_covered("""
            func a():
                return 1


            static func b():
                return 2
        """, [2, 6])

    def test_preserves_every_original_line(self):
        source = """
            func f(x):
                match x:
                    1:
                        return "one"
                    _:
                        return "other"
        """
        out, _covered, _declarations = instrument(source)
        original = textwrap.dedent(source).replace("    ", "\t").strip("\n").split("\n")
        emitted = [l for l in out.split("\n") if "CovTracker.hit" not in l]
        self.assertEqual(emitted, original, "instrumentation only adds lines, never alters them")

    def test_line_numbers_refer_to_the_original_source(self):
        out, covered, _declarations = instrument("""
            func f():
                var a = 1
                return a
        """)
        self.assertIn("CovTracker.hit(0, 2)", out)
        self.assertIn("CovTracker.hit(0, 3)", out)
        self.assertEqual(covered, [2, 3])


if __name__ == "__main__":
    unittest.main(verbosity=2)
