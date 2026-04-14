import json

with open("openapi.json", "r", encoding="utf-16") as f:
    data = json.load(f)

path_data = data.get("paths", {}).get("/api/quizzes/submission/{submission_id}", {})
if path_data:
    print(json.dumps(path_data, indent=2))
else:
    print("Path not found")
