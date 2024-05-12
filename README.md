# Swifty-Jira: A Command Line Jira Client with SSO Auth

Welcome to Swifty-Jira, a command line application written in Swift that allows you to use Jira as a terminal client with SSO authentication. This project is designed to make it easy for you to manage your Jira issues and view user information directly from your terminal.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Examples](#examples)
5. [Contributing](#contributing)

## Getting Started

To get started with Swifty-Jira, you'll need to checkout the repository from GitHub:

```
https://github.com/tinyprocessing/Swifty-Jira
```

This repository contains the source code for the application, which you can configure to suit your needs. If you don't want to modify the source code, you can use the application as is.

## Installation

To install Swifty-Jira, you can either run the `main.swift` file directly or use the `deploy.sh` script to build and install the application in the `/bin` folder.

Before running the application, you'll need to set an environment variable for the Jira server URL. You can do this by adding the following line to your `.bashrc` or `.zshrc` file:

```
export JIRA_URL=https://jira.server.com
```

Replace `https://jira.server.com` with the URL of your corporate Jira server.

## Usage

Swifty-Jira provides several commands to help you manage your Jira issues and view user information. Here are some examples:

### View User Information

To view information about the current Jira user, run the following command:

```
swifty-jira user info
```

This will display a table with information about the current user.

### List Projects

To view a list of all projects in your Jira account, run the following command:

```
swifty-jira project list
```

This will display a table with information about all projects in your account.

### List Issues

To view a list of all issues in your Jira account, run the following command:

```
swifty-jira issue list
```

This will display a table with information about all issues in your account, including their status and assignee.

### View Issue Details

To view the details of a specific issue, run the following command:

```
swifty-jira issue view --key <JIRA-KEY>
```

Replace `<JIRA-KEY>` with the key of the issue you want to view.

### Change Issue Status

To change the status of an issue, run the following command:

```
swifty-jira issue transition --key <JIRA-KEY> --status <STATUS> --resolution <RESOLUTION>
```

Replace `<JIRA-KEY>` with the key of the issue you want to change, `<STATUS>` with the new status of the issue, and `<RESOLUTION>` with the resolution of the issue.

### Create New Issue

To create a new issue, run the following command:

```
swifty-jira issue create --parent <PARENT-KEY> --summary "<SUMMARY>" --project <PROJECT-KEY> --assignee <ASSIGNEE>
```

Replace `<PARENT-KEY>` with the key of the parent issue (if applicable), `<SUMMARY>` with the summary of the issue, `<PROJECT-KEY>` with the key of the project, and `<ASSIGNEE>` with the username of the assignee.

## Examples

Here are some examples of how to use Swifty-Jira:

### View User Information
```
swifty-jira user info
```

### List Projects
```
swifty-jira project list
```

### List Issues
```
swifty-jira issue list
```

### View Issue Details
```
swifty-jira issue view --key MEMW-114
```

### Change Issue Status
```
swifty-jira issue transition --key MEMW-114 --status done --resolution done
```

### Create New Issue
```
swifty-jira issue create --parent MEMW-95 --summary "Export Lottie animations" --project MEMW --assignee vn55z6z
```

## Contributing

We welcome contributions to Swifty-Jira. If you have an idea for a new feature or have found a bug, please open an issue or submit a pull request.

Thank you for using Swifty-Jira!
