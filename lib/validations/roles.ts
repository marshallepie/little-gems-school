import { z } from "zod";
export const roleCodeSchema = z.enum(["admin", "teacher", "parent", "student"]);
export type RoleCode = z.infer<typeof roleCodeSchema>;
