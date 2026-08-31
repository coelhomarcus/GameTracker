export function displayName(user: { name: string | null; username: string }) {
  return user.name?.trim() || user.username;
}
