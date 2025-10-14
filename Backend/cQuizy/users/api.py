from ninja import Router, Schema

#! Instead of NinjaAPI, we use Router
router = Router(tags=['users'])  # The 'tags' are great for organizing docs

#* Test Endpoint ##################################################
@router.get("/hello")
def hello(request):
    return {"message": "Hello, your API works!"}

#* Register & Login Endpoint ##################################################
