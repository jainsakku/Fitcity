export async function getAuthUserId(req: Request): Promise<string> {
  const uid = req.headers.get("x-fitcity-uid");
  if (!uid) {
    throw new Error("Missing x-fitcity-uid header");
  }
  return uid;
}
