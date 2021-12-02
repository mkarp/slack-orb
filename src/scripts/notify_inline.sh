python -c "import http
import http.client
import json
import os
import platform
import re
import tempfile


def tmp_dir():
    return \"/tmp\" if platform.system() == \"Darwin\" else tempfile.gettempdir()


def cat(file_path):
    with open(file_path, \"r\") as f:
        return f.read()


def env_var(name):
    if name in os.environ:
        return os.environ[name]
    return None


def fill_env_vars(template):
    template_strings = re.findall(r\"\\\${[A-Za-z0-9_]+}\", template)
    env_vars = list(map(lambda s: s[2:-1], template_strings))
    result = template
    for env_var in env_vars:
        if env_var in os.environ:
            result = result.replace(\"\${\" + env_var + \"}\", os.environ[env_var])
    return result


def parse_cci_status():
    return (
        cat(os.path.join(tmp_dir(), \"SLACK_JOB_STATUS\"))
        .replace(\"CCI_STATUS=\", \"\")
        .replace('\"', \"\")
    )


def build_message_body(custom_template, template, channel):
    # Send message
    #   If sending message, default to custom template,
    #   if none is supplied, check for a pre-selected template value.
    #   If none, error.
    chosen_template = None
    if custom_template:
        chosen_template = modify_custom_template(custom_template)
    elif template:
        chosen_template = template
    else:
        raise Exception(
            \"Error: No message template selected.\\n\"
            + \"Select either a custom template or one of the pre-included ones via the 'custom' or 'template' parameters.\"
        )
    chosen_template = fill_env_vars(chosen_template)
    result_template = json.loads(chosen_template)
    result_template[\"channel\"] = channel
    return json.dumps(result_template)


def post_to_slack(body, channels, access_token, igone_errors=False):
    # Post once per channel listed by the channel parameter
    #    The channel must be modified in SLACK_MSG_BODY

    for channel in channels.split(\",\"):
        print(f\"Sending to Slack Channel: {channel}\")
        body_json = json.loads(body)
        body_json[\"channel\"] = channel

        conn = http.client.HTTPSConnection(\"slack.com\")
        conn.request(
            \"POST\",
            \"/api/chat.postMessage\",
            json.dumps(body_json),
            {
                \"Content-type\": \"application/json; charset=utf-8\",
                \"Authorization\": f\"Bearer {access_token}\",
            },
        )

        response = conn.getresponse()

        if response.status >= 300:
            status = response.status
            body = response.read()
            raise Exception(f\"POST request failed {status} {body}\")

        response_json = json.loads(response.read())
        if not igone_errors and \"error\" in response_json:
            print(
                f\"Slack API returned an error message: {response_json['error']}\\n\\n\"
                + \"View the Setup Guide: https://github.com/CircleCI-Public/slack-orb/wiki/Setup\"
            )
            raise Exception(response_json[\"error\"])


def modify_custom_template(custom_template):
    # Inserts the required \"text\" field to the custom json template from block
    # kit builder.
    custom_template_json = json.loads(custom_template)
    if not \"text\" in custom_template_json:
        custom_template_json[\"text\"] = \"\"
    return json.dumps(custom_template_json)


def checkenv_vars(webhook, access_token, channel):
    if webhook:
        raise Exception(
            \"It appears you have a Slack Webhook token present in this job.\\n\"
            + \"Please note, Webhooks are no longer used for the Slack Orb (v4 +).\\n\"
            + \"Follow the setup guide available in the wiki: https://github.com/CircleCI-Public/slack-orb/wiki/Setup\"
        )
    if not access_token:
        raise Exception(
            \"In order to use the Slack Orb (v4 +), an OAuth token must be present via the SLACK_ACCESS_TOKEN environment variable.\\n\"
            + \"Follow the setup guide available in the wiki: https://github.com/CircleCI-Public/slack-orb/wiki/Setup\"
        )
    if not channel:
        raise Exception(
            \"No channel was provided. Enter value for SLACK_DEFAULT_CHANNEL env var, or channel parameter.\"
        )


def filter_by(patterns, test_string):
    \"\"\"
    Returns True if Slack message can be posted.
    When thinking in Bash's terms:
        True == continue execution
        False == exit(0)
    \"\"\"
    if not patterns or not test_string:
        return True

    # If any pattern supplied matches the current branch or the current tag,
    # proceed; otherwise, exit with message.
    for pattern in patterns.split(\",\"):
        if re.match(pattern.strip(), test_string):
            return True
    else:
        # Don't send message
        print(
            \"NO SLACK ALERT\\n\\n\"
            + f\"Current reference {test_string} does not match any matching parameter.\\n\"
            + f\"Current matching pattern: {pattern}.\"
        )
    return False


def should_post(
    cci_status,
    event,
    branch_pattern=None,
    branch=None,
    tag_pattern=None,
    tag=None,
):
    if cci_status == event or event == \"always\":
        # In the event the Slack notification would be sent, first ensure it is
        # allowed to trigger on this branch or this tag.
        if filter_by(branch_pattern, branch) or filter_by(tag_pattern, tag):
            print(\"Posting status\")
            return True
    else:
        # Don't send message
        print(
            \"NO SLACK ALERT\\n\\n\"
            + f\"This command is set to send an alert on: {event}.\\n\"
            + f\"Current status: {cci_status}.\"
        )
    return False


if __name__ == \"__main__\":
    channel = env_var(\"SLACK_DEFAULT_CHANNEL\") or env_var(\"SLACK_PARAM_CHANNEL\")

    checkenv_vars(env_var(\"SLACK_WEBHOOK\"), env_var(\"SLACK_ACCESS_TOKEN\"), channel)

    cci_status = parse_cci_status()

    if should_post(
        cci_status,
        env_var(\"SLACK_PARAM_EVENT\"),
        branch_pattern=env_var(\"SLACK_PARAM_BRANCHPATTERN\"),
        branch=env_var(\"CIRCLE_BRANCH\"),
        tag_pattern=env_var(\"SLACK_PARAM_TAGPATTERN\"),
        tag=env_var(\"CIRCLE_TAG\"),
    ):
        body = build_message_body(
            env_var(\"SLACK_PARAM_CUSTOM\"),
            env_var(\"SLACK_PARAM_TEMPLATE\"),
            env_var(\"SLACK_DEFAULT_CHANNEL\"),
        )
        post_to_slack(
            body,
            channel,
            env_var(\"SLACK_ACCESS_TOKEN\"),
            igone_errors=env_var(\"SLACK_PARAM_IGNORE_ERRORS\"),
        )
"