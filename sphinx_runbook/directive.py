"""Custom directives emitting semantic nodes at author-chosen positions."""

from docutils.parsers.rst import Directive, directives

from sphinx_runbook.nodes import runbook_image


class RunbookImageDirective(Directive):
    """``runbook-image`` — reference an image attachment by path."""

    has_content = False
    required_arguments = 1
    optional_arguments = 0
    final_argument_whitespace = True
    option_spec = {
        "alt": directives.unchanged,
        "caption": directives.unchanged,
    }

    def run(self):
        node = runbook_image()
        node["path"] = self.arguments[0]
        node["alt"] = self.options.get("alt", "")
        node["caption"] = self.options.get("caption", "")
        source, line = self.state_machine.get_source_and_line(self.lineno)
        node["source"] = source
        node["line"] = line
        return [node]
