///|
#export_name("uppercaseFromMoonBit")
pub async fn uppercase_from_moonbit(input : Bytes) -> Bytes {
  napi_native_task("uppercase", input)
}
