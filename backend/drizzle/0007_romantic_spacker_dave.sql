ALTER TABLE "posts" ADD COLUMN "activity_status" "game_entry_status";--> statement-breakpoint
-- Backfill: content de post type='activity' é sempre gerado por ACTIVITY_VERB
-- (nunca digitado por usuário), então casar por substring é seguro aqui.
UPDATE "posts" SET "activity_status" = 'completed' WHERE "type" = 'activity' AND "content" LIKE '%zerou%';--> statement-breakpoint
UPDATE "posts" SET "activity_status" = 'playing' WHERE "type" = 'activity' AND "content" LIKE '%começou a jogar%';--> statement-breakpoint
UPDATE "posts" SET "activity_status" = 'backlog' WHERE "type" = 'activity' AND "content" LIKE '%backlog%';