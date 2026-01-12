import subprocess
import re
from collections import defaultdict
from pathlib import Path

METHOD_RE = re.compile(
    r"\[DEBUG\]\s+\[Method Inventory Check\]\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_$.]+)\s+([A-Za-z0-9_]+)"
)

SRC = Path("dev-test/src/main")
TEST = Path("dev-test/src/test")


def run_checkstyle(target_dir):
    cmd = [
        "java",
        "-cp",
        "resources/checkstyle-12.3.0-all.jar;build/MethodInventoryCheck.jar",
        "com.puppycrawl.tools.checkstyle.Main",
        "-c",
        "./resources/method_inventory_check_config.xml",
        str(target_dir),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.stdout


def collect_methods(output):
    result = defaultdict(set)
    for line in output.splitlines():
        m = METHOD_RE.search(line)
        if m:
            cls, classPath, method = m.groups()
            result[f"{classPath}.{cls}"].add(method)
    return result


def generate_html_report(
    missing_tests, src_methods, output_file="./build/missing_unit_test_report.html"
):
    """
    Generate a cohesive HTML report:
    - Class name separated from classpath
    - Additional column for classpath
    - Red background for failed, green for passed
    - Click to expand/collapse method lists
    """

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Unit Test Report</title>
<style>
    body {{
        font-family: Arial, sans-serif;
        font-size: 14px;
        margin: 20px;
        background-color: #f9f9f9;
    }}
    h1 {{
        font-size: 20px;
        margin-bottom: 10px;
    }}
    table {{
        border-collapse: collapse;
        width: 100%;
    }}
    th, td {{
        border: 1px solid #ccc;
        padding: 6px 10px;
        text-align: left;
        vertical-align: top;
    }}
    th {{
        background-color: #eee;
    }}
    tr.failed {{ background-color: #f8d7da; cursor: pointer; }}
    tr.passed {{ background-color: #d4edda; cursor: pointer; }}
    tr.details {{ display: none; background-color: #fff3cd; }}
    .method-list {{ margin: 5px 0; padding-left: 20px; }}
    .method-list li {{ line-height: 1.2; }}
</style>
<script>
function toggleRow(id) {{
    var elem = document.getElementById(id);
    elem.style.display = (elem.style.display === 'table-row') ? 'none' : 'table-row';
}}
</script>
</head>
<body>
<h1>Unit Test Report</h1>
<p>Total classes analyzed: {len(src_methods)}</p>

<table>
<tr>
<th>Class</th>
<th>Classpath</th>
<th>Missing Methods</th>
</tr>
"""

    # Sort failed classes first
    sorted_classes = sorted(
        src_methods.keys(),
        key=lambda cls: (
            cls in missing_tests and len(missing_tests[cls]["missing_methods"]) > 0,
            cls,
        ),
        reverse=True,
    )

    for i, full_class in enumerate(sorted_classes):
        info = missing_tests.get(
            full_class, {"missing_class": False, "missing_methods": []}
        )
        missing_count = len(info["missing_methods"]) if info["missing_methods"] else 0
        div_id = f"details_{i}"

        # Extract simple class name
        class_name = full_class.split(".")[-1]

        html += f"<tr class='{'failed' if missing_count>0 else 'passed'}' onclick=\"toggleRow('{div_id}')\">"
        html += f"<td>{class_name}</td>"
        html += f"<td>{full_class}</td>"
        html += f"<td>{missing_count}</td>"
        html += "</tr>"

        # Details row
        html += f"<tr id='{div_id}' class='details'><td colspan='3'>"

        if missing_count > 0:
            html += "<b>Missing methods:</b><ul class='method-list'>"
            for m in info["missing_methods"]:
                html += f"<li>{m}</li>"
            html += "</ul>"
        else:
            html += "<b>Missing methods:</b> None<br>"

        present_methods = sorted(src_methods.get(full_class, []))
        html += "<b>Present methods:</b><ul class='method-list'>"
        for m in present_methods:
            html += f"<li>{m}</li>"
        html += "</ul>"

        html += "</td></tr>"

    html += "</table></body></html>"

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"Cohesive HTML report generated: {output_file}")


# --- Run ---
src_out = run_checkstyle(SRC)
test_out = run_checkstyle(TEST)

src_methods = collect_methods(src_out)
test_methods = collect_methods(test_out)

# --- Analyze ---
missing_tests = {}  # dict with detailed info

for cls, methods in src_methods.items():
    test_cls = cls + "Test"

    if test_cls not in test_methods:
        # Whole test class is missing
        missing_tests[cls] = {"missing_class": True, "missing_methods": sorted(methods)}
        continue

    # Determine which test methods are missing
    expected_tests = {f"test{m[0].upper()}{m[1:]}" for m in methods}
    actual_tests = test_methods[test_cls]

    missing = sorted(expected_tests - actual_tests)
    if missing:
        missing_tests[cls] = {"missing_class": False, "missing_methods": missing}

# --- Console Output ---
if not missing_tests:
    print("All classes fully tested")
else:
    print("Missing unit tests:")
    for cls, info in sorted(missing_tests.items()):
        line = f"- {cls}"
        if info["missing_class"]:
            line += " (missing test class)"
        print(line)
        if info["missing_methods"] and not info["missing_class"]:
            print(f"    Missing methods: {', '.join(info['missing_methods'])}")

# --- HTML Report ---
generate_html_report(missing_tests, src_methods)
