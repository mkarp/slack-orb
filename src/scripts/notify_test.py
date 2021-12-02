import pytest
import json
import os
import unittest.mock as mock


import notify


def here(file):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), file)


def test_1_skip_message_on_no_event():
    cci_status = "success"
    event = "fail"
    assert notify.should_post(cci_status, event) == False


def test_2_modify_custom_template():
    custom_template = notify.cat(here("../tests/sampleCustomTemplate.json"))
    result = notify.modify_custom_template(custom_template)
    assert json.loads(result)["text"] == ""


def test_3_modify_custom_template_with_existing_key():
    custom_template = notify.cat(here("../tests/sampleCustomTemplateWithText.json"))
    result = notify.modify_custom_template(custom_template)
    assert json.loads(result)["text"] == "User-Added text key"


def test_4_modify_custom_template_with_environment_variable_in_link():
    test_link_url = "http://circleci.com"
    custom_template = notify.cat(here("../tests/sampleCustomTemplateWithLink.json"))
    channel = "xyz"
    with mock.patch("os.environ", {"TESTLINKURL": test_link_url}):
        assert (
            notify.build_message_body(custom_template, None, channel)
            == '{"blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": "Sample link using environment variable in markdown <'
            + test_link_url
            + '|LINK >"}}], "text": "", "channel": "'
            + channel
            + '"}'
        )


def test_5_modify_custom_template_special_chars():
    custom_template = notify.cat(
        here("../tests/sampleCustomTemplateWithSpecialChars.json")
    )
    channel = "xyz"
    assert (
        notify.build_message_body(custom_template, None, channel)
        == '{"blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": "These asterisks are not `glob`  patterns **t** (parentheses\'). [Link](https://example.org)"}}], "text": "", "channel": "'
        + channel
        + '"}'
    )


def test_6_filter_by_match_all_default(capsys):
    branch_pattern = ".+"
    branch = "xyz-123"
    assert (
        notify.filter_by(branch_pattern, branch) == True
    )  # In any case, this should return a 0 exit as to not block a build/deployment.
    assert capsys.readouterr().out == ""  # Should match any branch: No output error


def test_7_filter_by_string(capsys):
    branch_pattern = notify.cat(here("../tests/sampleBranchFilters.txt"))
    branch = "master"
    assert (
        notify.filter_by(branch_pattern, branch) == True
    )  # In any case, this should return a 0 exit as to not block a build/deployment.
    assert capsys.readouterr().out == ""  # "master" is in the list: No output error


def test_8_filter_by_regex_numbers(capsys):
    branch_pattern = notify.cat(here("../tests/sampleBranchFilters.txt"))
    branch = "pr-123"
    assert (
        notify.filter_by(branch_pattern, branch) == True
    )  # In any case, this should return a 0 exit as to not block a build/deployment.
    assert capsys.readouterr().out == ""  # "pr-[0-9]+" should match: No output error


def test_9_filter_by_non_match(capsys):
    branch_pattern = notify.cat(here("../tests/sampleBranchFilters.txt"))
    branch = "x"
    assert (
        notify.filter_by(branch_pattern, branch) == False
    )  # In any case, this should return a 0 exit as to not block a build/deployment.
    assert capsys.readouterr().out.startswith(
        "NO SLACK ALERT"
    )  # "x" is not included in the filter. Error message expected.


def test_10_filter_by_no_partial_match(capsys):
    branch_pattern = notify.cat(here("../tests/sampleBranchFilters.txt"))
    branch = "pr-"
    assert (
        notify.filter_by(branch_pattern, branch) == False
    )  # In any case, this should return a 0 exit as to not block a build/deployment.
    assert capsys.readouterr().out.startswith(
        "NO SLACK ALERT"
    )  # Filter dictates that numbers should be included. Error message expected.


def test_11_filter_by_slack_param_branchpattern_is_empty():
    branch = "master"
    assert (
        notify.filter_by(None, branch) == True
    )  # In any case, this should return a 0 exit as to not block a build/deployment.


def test_12_filter_by_circle_branch_is_empty():
    assert (
        notify.filter_by(None, None) == True
    )  # In any case, this should return a 0 exit as to not block a build/deployment.
