ALTER TABLE "posts" ADD COLUMN "game_id" uuid;--> statement-breakpoint
ALTER TABLE "posts" ADD CONSTRAINT "posts_game_id_games_id_fk" FOREIGN KEY ("game_id") REFERENCES "public"."games"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "game_entries_game_status_idx" ON "game_entries" USING btree ("game_id","status");--> statement-breakpoint
CREATE INDEX "posts_game_id_idx" ON "posts" USING btree ("game_id");