import importlib

import click


def find_question_by_id(questions, question_id):
    """
    Find a question object by its ID from a list of questions.

    :param questions: List of question objects.
    :param question_id: The ID of the question to find.
    :return: The question object with the specified ID, or None if not found.
    """
    for question in questions:
        if question.id == question_id:
            return question


def make_envs(envs_configuration):
    """
    Create a dictionary of environments based on the provided configuration.

    :param envs_configuration: List of environment configuration objects.
    :return: Dictionary of environments with their respective configurations.
    """
    envs = {}
    for env_configuration in envs_configuration:
        envs[env_configuration.scope.value] = []
        for scope_env in env_configuration.envs:
            envs[env_configuration.scope.value].append(
                {
                    "name": scope_env.name,
                    "value": scope_env.default,
                }
            )

    return envs


def proceed_with_questions(deployment_dir, all_envs, questions, entrypoint_id):
    """
    Proceed with asking questions and updating environments based on user input.

    :param deployment_dir: The deployment directory.
    :param all_envs: The current environments dictionary.
    :param questions: List of question objects.
    :param entrypoint_id: The ID of the entrypoint question.
    :return: Updated environments dictionary and a boolean indicating if the process was interrupted.
    """
    next_question_id = entrypoint_id
    action = "proceed"

    all_exposed = []
    scope_envs = []
    while action in ["proceed", "exit", "complete"]:
        if action == "exit":
            return all_envs, True

        if action == "complete":
            break

        question_obj = find_question_by_id(questions, next_question_id)
        answer_ctx, interrupted = ask_question(deployment_dir, question_obj)
        if interrupted:
            return all_envs, True

        next_question_id, action, exposed = next_question(deployment_dir, questions, question_obj, answer_ctx)

        scope_envs.append(answer_ctx)
        all_exposed.extend(exposed)

    envs = update_envs(all_envs, all_exposed, scope_envs)
    return envs, False


def ask_question(deployment_dir, question_obj):
    """
    Ask a question to the user and validate the response.

    :param deployment_dir: The deployment directory.
    :param question_obj: The question object containing the question details.
    :return: A dictionary containing the name and value of the answered environment variable,
        and a boolean indicating if the process was interrupted.
    """
    predefined_funcs_module = importlib.import_module("cli.dynamic_configuration.predefined_funcs")

    keep_asking = True
    while keep_asking:
        env = question_obj.var
        try:
            val = input(f"\t- {question_obj.question}")
        except KeyboardInterrupt:
            return {
                "name": env,
                "value": "",
            }, True

        if val == "":
            val = question_obj.default

        validations_passed = True
        for validation in question_obj.validation:
            func = validation.func.value
            args = validation.args
            replaced_args = []
            for arg in args:
                arg = arg.replace(f"${env}", str(val))
                replaced_args.append(arg)

            success_criteria = validation.success.value
            try:
                runnable = getattr(predefined_funcs_module, func)
                validation_result = runnable(deployment_dir, *replaced_args)
                if validation_result == "" and success_criteria == "notempty":
                    raise Exception("validation result is empty")
            except Exception:
                msg = click.style(validation.err_msg, fg="red")
                click.echo(f"\t {msg}")
                validations_passed = False

        if validations_passed:
            keep_asking = False

    for post_processing in question_obj.post_processing:
        func = post_processing.func.value
        runnable = getattr(predefined_funcs_module, func)
        val = runnable(deployment_dir, val)

    return {
        "name": env,
        "value": val,
    }, False


def next_question(deployment_dir, questions, question_obj, answer_ctx):
    """
    Determine the next question to ask based on the current question's answer.

    :param deployment_dir: The deployment directory.
    :param questions: List of question objects.
    :param question_obj: The current question object.
    :param answer_ctx: The context of the answered question.
    :return: The ID of the next question, the action to take, and a list of exposed environments.
    """
    predefined_funcs_module = importlib.import_module("cli.dynamic_configuration.predefined_funcs")
    next_condition_value = question_obj.next.value.replace(f"${answer_ctx['name']}", str(answer_ctx["value"]))
    for condition in question_obj.next.conditions:
        if condition.when != next_condition_value:
            continue

        next_question_id = condition.question_id
        action = condition.action.value
        exposed = []

        for expose in condition.expose:
            exposed_env = expose.name
            func = expose.func.value
            runnable = getattr(predefined_funcs_module, func)
            args = expose.args
            replaced_args = []
            for arg in args:
                arg = arg.replace(f"${answer_ctx['name']}", str(answer_ctx["value"]))
                replaced_args.append(arg)

            for previous_exposed in exposed:
                name = previous_exposed["name"]
                value = previous_exposed["value"]
                args = replaced_args
                replaced_args = []
                for arg in args:
                    arg = arg.replace(f"${name}", str(value))
                    replaced_args.append(arg)

            exposed_val = runnable(deployment_dir, *replaced_args)
            exposed.append(
                {
                    "name": exposed_env,
                    "value": exposed_val,
                }
            )

        return next_question_id, action, exposed


def update_envs(all_envs, all_exposed, scope_envs):
    """
    Update the environments with the exposed variables.

    :param all_envs: The current environments dictionary.
    :param all_exposed: List of all exposed environment variables.
    :param scope_envs: List of scope-specific environment variables.
    :return: Updated environments dictionary.
    """
    exposed_mapping = make_exposed_mapping(all_exposed)
    for _, envs in all_envs.items():
        for env in envs:
            overridden = exposed_mapping.get(env["name"])
            if overridden:
                env["value"] = overridden
    return all_envs


def make_exposed_mapping(all_exposed):
    """
    Create a mapping of exposed environment variables.

    :param all_exposed: List of all exposed environment variables.
    :return: Dictionary mapping environment variable names to their values.
    """
    mapping = {}
    for exposed in all_exposed:
        name = exposed["name"]
        value = exposed["value"]
        mapping[name] = value
    return mapping


def enrich_envs(envs, license_key, registry_user, registry_pwd):
    """
    Enrich the environments with additional variables like LICENSE_KEY, REGISTRY_USER, and REGISTRY_PWD.

    :param envs: The current environments dictionary.
    :param license_key: The license key to be added.
    :param registry_user: The registry user to be added.
    :param registry_pwd: The registry password to be added.
    :return: Updated environments dictionary.
    """
    envs[".config.env"].append({"name": "LICENSE_KEY", "value": license_key})
    if ".pre.deployment.ops.env" in envs:
        envs[".pre.deployment.ops.env"].append({"name": "REGISTRY_USER", "value": registry_user})
        envs[".pre.deployment.ops.env"].append({"name": "REGISTRY_PWD", "value": registry_pwd})
    return envs


def dump_envs(all_envs, deployment_dir):
    """
    Dump the environments to files in the deployment directory.

    :param all_envs: The current environments dictionary.
    :param deployment_dir: The deployment directory.
    """
    for scope, scope_envs in all_envs.items():
        scope_envs_as_mapping = make_exposed_mapping(scope_envs)
        env_file_path = f"{deployment_dir}/{scope}"
        with open(env_file_path, "w") as file:
            for key, value in scope_envs_as_mapping.items():
                # Manually escape double quotes within the value
                escaped_value = value.replace('"', '\\"')
                # Wrap the value in double quotes
                file.write(f'{key}="{escaped_value}"\n')
