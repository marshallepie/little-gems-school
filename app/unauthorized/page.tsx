export const dynamic = "force-static";

export default function UnauthorizedPage() {
  return (
    <main className="mx-auto max-w-xl space-y-4 p-6">
      <p className="font-semibold text-violet-700">Little Gems School</p>
      <h1 className="text-3xl font-bold">Access denied</h1>
      <p>You are signed in, but your account does not have permission to access this area.</p>
    </main>
  );
}
