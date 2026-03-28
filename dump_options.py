import json

with open("openapi.json", "r", encoding="utf-16") as f:
    data = json.load(f)

schemas = data.get("components", {}).get("schemas", {})

def dump_schema(name):
    if name in schemas:
        print(f"====== {name} ======")
        print(json.dumps(schemas[name], indent=2))
    else:
        print(f"{name} not found")

dump_schema("AnswerOutSchema")
dump_schema("StudentOptionSchema")
