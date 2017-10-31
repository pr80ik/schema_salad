from .util import get_data
import unittest
from schema_salad.main import to_one_line_messages
from schema_salad.schema import load_schema, load_and_validate
from schema_salad.sourceline import strip_dup_lineno
from schema_salad.validate import ValidationException
from os.path import normpath
import re
import six

class TestPrintOneline(unittest.TestCase):
    def test_print_oneline(self):
        # Issue #135
        document_loader, avsc_names, schema_metadata, metaschema_loader = load_schema(
            get_data(u"tests/test_schema/CommonWorkflowLanguage.yml"))

        src = "test15.cwl"
        with self.assertRaises(ValidationException):
            try:
                load_and_validate(document_loader, avsc_names,
                                  six.text_type(get_data("tests/test_schema/"+src)), True)
            except ValidationException as e:
                msgs = to_one_line_messages(str(e)).splitlines()
                self.assertEqual(len(msgs), 2)
                m = re.match(r'^(.+:\d+:\d+:)(.+)$', msgs[0])
                self.assertTrue(msgs[0].endswith(src+":11:7: invalid field `invalid_field`, expected one of: 'loadContents', 'position', 'prefix', 'separate', 'itemSeparator', 'valueFrom', 'shellQuote'"))
                self.assertTrue(msgs[1].endswith(src+":12:7: invalid field `another_invalid_field`, expected one of: 'loadContents', 'position', 'prefix', 'separate', 'itemSeparator', 'valueFrom', 'shellQuote'"))
                print("\n", e)
                raise

    def test_print_oneline_for_invalid_yaml(self):
        # Issue #137
        document_loader, avsc_names, schema_metadata, metaschema_loader = load_schema(
            get_data(u"tests/test_schema/CommonWorkflowLanguage.yml"))

        src = "test16.cwl"
        fullpath = normpath(get_data("tests/test_schema/"+src))
        with self.assertRaises(RuntimeError):
            try:
                load_and_validate(document_loader, avsc_names,
                                  six.text_type(fullpath), True)
            except RuntimeError as e:
                msg = re.sub(r'[\s\n]+', ' ', strip_dup_lineno(six.text_type(e)))
                # convert Windows path to Posix path
                if '\\' in fullpath:
                    fullpath = '/'+fullpath.replace('\\', '/')
                self.assertEqual(msg, 'while scanning a simple key in "file://%s", line 9, column 7 could not find expected \':\' in "file://%s", line 10, column 1' % (fullpath, fullpath))
                print("\n", e)
                raise

    def test_print_oneline_for_errors_in_the_same_line(self):
        # Issue #136
        document_loader, avsc_names, schema_metadata, metaschema_loader = load_schema(
            get_data(u"tests/test_schema/CommonWorkflowLanguage.yml"))

        src = "test17.cwl"
        with self.assertRaises(ValidationException):
            try:
                load_and_validate(document_loader, avsc_names,
                                  six.text_type(get_data("tests/test_schema/"+src)), True)
            except ValidationException as e:
                msgs = to_one_line_messages(str(e)).splitlines()
                self.assertEqual(len(msgs), 2)
                self.assertTrue(msgs[0].endswith(src+":13:5: missing required field `id`"))
                self.assertTrue(msgs[1].endswith(src+":13:5: invalid field `aa`, expected one of: 'label', 'secondaryFiles', 'format', 'streamable', 'doc', 'id', 'outputBinding', 'type'"))
                print("\n", e)
                raise