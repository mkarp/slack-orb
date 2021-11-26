import os


def main():
    print(os.environ["SLACK_WEBHOOK"])
    print(os.environ["SLACK_ACCESS_TOKEN"])
    print(os.environ["SLACK_PARAM_CHANNEL"])


if __name__ == "__main__":
    main()
