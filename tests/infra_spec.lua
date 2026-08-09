require("tests.wow_stub")
describe("test infrastructure", function()
  it("runs under lua 5.1 semantics", function()
    assert.equal("50", ("%d"):format(50))
    assert.is_function(setfenv) -- 5.1 only
  end)
end)
