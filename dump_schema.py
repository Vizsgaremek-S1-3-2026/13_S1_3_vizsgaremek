import json

with open("openapi.json", "r", encoding="utf-16") as f:
    data = json.load(f)

schemas = data.get("components", {}).get("schemas", {})
sub_out = schemas.get("SubmissionOutSchema")
if sub_out:
    print("====== SubmissionOutSchema ======")
    print(json.dumps(sub_out, indent=2))
else:
    print("SubmissionOutSchema not found")

point_update = schemas.get("PointUpdateItemSchema")
if point_update:
    print("====== PointUpdateItemSchema ======")
    print(json.dumps(point_update, indent=2))
