import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";

const mocks = vi.hoisted(() => ({
  linkProps: [] as { href?: string; prefetch?: boolean }[],
  useRouter: vi.fn(),
}));

vi.mock("next/link", () => ({
  default: (props: { href?: string; prefetch?: boolean }) => {
    mocks.linkProps.push(props);
    return null;
  },
}));
vi.mock("next/navigation", () => ({ useRouter: mocks.useRouter }));
vi.mock("@/lib/supabase/browser", () => ({ createClient: vi.fn() }));

import { PortalAccountControls } from "../../components/portal-account-controls";

describe("PortalAccountControls", () => {
  beforeEach(() => {
    mocks.linkProps.length = 0;
    mocks.useRouter.mockReturnValue({ replace: vi.fn(), refresh: vi.fn() });
  });

  it("does not prefetch the server-authenticated profile route", () => {
    renderToStaticMarkup(<PortalAccountControls />);

    expect(mocks.linkProps.some(({ href, prefetch }) => href === "/profile" && prefetch === false)).toBe(true);
  });
});
