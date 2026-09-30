-- 022_live_audio_spaces.sql
--
-- Live Audio Spaces / Trading Floors for TradeX Community
--
-- Enables real-time drop-in audio rooms, live market discussions, pinned trade setups,
-- listener/speaker participant state, in-room chat messages, Q&A question queues,
-- live sentiment polls, and scheduled room reminders with push notifications.
--
-- Mirrors models in lib/features/community/models/community_models.dart:
-- - LiveAudioRoom (status: live, scheduled, ended)
-- - LivePinnedSetup (ticker, side, entry, SL, target, note)
-- - Participant state (host, speaker, listener, muted, hand raised)

BEGIN;

-- 1. Live Audio Rooms Table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_live_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    topic TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'Options Trading',
    status TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live', 'scheduled', 'ended')),
    listener_count INTEGER NOT NULL DEFAULT 1 CHECK (listener_count >= 0),
    speaker_count INTEGER NOT NULL DEFAULT 1 CHECK (speaker_count >= 1),
    started_at TIMESTAMPTZ,
    scheduled_for TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    recording_available BOOLEAN NOT NULL DEFAULT true,
    recording_url TEXT,
    tags TEXT[] NOT NULL DEFAULT '{}',
    -- Pinned trade setup on stage
    pinned_ticker TEXT,
    pinned_side TEXT CHECK (pinned_side IS NULL OR pinned_side IN ('LONG', 'SHORT')),
    pinned_entry NUMERIC(16, 4),
    pinned_stop_loss NUMERIC(16, 4),
    pinned_target NUMERIC(16, 4),
    pinned_note TEXT,
    -- Live sentiment poll
    poll_bullish_votes INTEGER NOT NULL DEFAULT 0 CHECK (poll_bullish_votes >= 0),
    poll_bearish_votes INTEGER NOT NULL DEFAULT 0 CHECK (poll_bearish_votes >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Participants Table (Host, Speakers, Listeners)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_live_room_participants (
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    role TEXT NOT NULL DEFAULT 'listener' CHECK (role IN ('host', 'cohost', 'speaker', 'listener')),
    is_muted BOOLEAN NOT NULL DEFAULT true,
    is_hand_raised BOOLEAN NOT NULL DEFAULT false,
    hand_raised_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (room_id, user_id)
);

-- 3. Live Room In-Stage Messages / Real-Time Chat
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_live_room_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    message TEXT NOT NULL CHECK (length(trim(message)) > 0),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Live Room Questions (Q&A queue with community upvotes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_live_room_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    question TEXT NOT NULL CHECK (length(trim(question)) > 0),
    upvotes_count INTEGER NOT NULL DEFAULT 0 CHECK (upvotes_count >= 0),
    is_answered BOOLEAN NOT NULL DEFAULT false,
    answered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_live_room_question_upvotes (
    question_id UUID NOT NULL REFERENCES community_live_room_questions(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (question_id, user_id)
);

-- 5. Upcoming Space Reminders
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_live_room_reminders (
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    notified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (room_id, user_id)
);

-- 6. Indexes for High-Concurrency Live Audio Events
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_community_live_rooms_status
    ON community_live_rooms(status, scheduled_for, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_live_rooms_host
    ON community_live_rooms(host_id);

CREATE INDEX IF NOT EXISTS idx_community_live_room_participants_room
    ON community_live_room_participants(room_id, role);

CREATE INDEX IF NOT EXISTS idx_community_live_room_messages_room
    ON community_live_room_messages(room_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_live_room_questions_room
    ON community_live_room_questions(room_id, is_answered, upvotes_count DESC);

CREATE INDEX IF NOT EXISTS idx_community_live_room_reminders_user
    ON community_live_room_reminders(user_id);


-- 7. Trigger: Maintain Live Listener & Speaker Counts
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_community_live_room_participant_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_room_id UUID := COALESCE(NEW.room_id, OLD.room_id);
    v_listeners INTEGER;
    v_speakers INTEGER;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE role = 'listener'),
        COUNT(*) FILTER (WHERE role IN ('host', 'cohost', 'speaker'))
    INTO v_listeners, v_speakers
    FROM community_live_room_participants
    WHERE room_id = v_room_id;

    UPDATE community_live_rooms
    SET 
        listener_count = GREATEST(1, v_listeners + v_speakers),
        speaker_count = GREATEST(1, v_speakers),
        updated_at = now()
    WHERE id = v_room_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS community_live_room_participant_counts_trg ON community_live_room_participants;
CREATE TRIGGER community_live_room_participant_counts_trg
AFTER INSERT OR UPDATE OF role OR DELETE ON community_live_room_participants
FOR EACH ROW EXECUTE FUNCTION trg_community_live_room_participant_counts();


-- 8. Trigger: Maintain Question Upvote Counts
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_community_live_room_question_upvotes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_live_room_questions
        SET upvotes_count = upvotes_count + 1
        WHERE id = NEW.question_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_live_room_questions
        SET upvotes_count = GREATEST(0, upvotes_count - 1)
        WHERE id = OLD.question_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS community_live_room_question_upvotes_trg ON community_live_room_question_upvotes;
CREATE TRIGGER community_live_room_question_upvotes_trg
AFTER INSERT OR DELETE ON community_live_room_question_upvotes
FOR EACH ROW EXECUTE FUNCTION trg_community_live_room_question_upvotes();


-- 9. Helper RPC Procedures for Client Actions
-- ---------------------------------------------------------------------------

-- 9a. Tune into Live Space
CREATE OR REPLACE FUNCTION tune_into_live_room(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_room RECORD;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_room FROM community_live_rooms WHERE id = p_room_id;
    IF v_room IS NULL THEN
        RAISE EXCEPTION 'Live room not found';
    END IF;

    INSERT INTO community_live_room_participants (
        room_id,
        user_id,
        role,
        is_muted,
        is_hand_raised,
        joined_at,
        last_seen_at
    )
    VALUES (
        p_room_id,
        v_user,
        (CASE WHEN v_room.host_id = v_user THEN 'host' ELSE 'listener' END),
        (CASE WHEN v_room.host_id = v_user THEN false ELSE true END),
        false,
        now(),
        now()
    )
    ON CONFLICT (room_id, user_id)
    DO UPDATE SET
        last_seen_at = now(),
        is_muted = EXCLUDED.is_muted;

    RETURN jsonb_build_object(
        'success', true,
        'room_id', p_room_id,
        'title', v_room.title,
        'status', v_room.status
    );
END;
$$;

-- 9b. Leave Live Space
CREATE OR REPLACE FUNCTION leave_live_room(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM community_live_room_participants
    WHERE room_id = p_room_id AND user_id = v_user;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 9c. Toggle Hand Raised in Stage
CREATE OR REPLACE FUNCTION toggle_live_room_hand(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_hand_raised BOOLEAN;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT is_hand_raised INTO v_hand_raised
    FROM community_live_room_participants
    WHERE room_id = p_room_id AND user_id = v_user;

    IF v_hand_raised IS NULL THEN
        RAISE EXCEPTION 'Not a participant in this room';
    END IF;

    UPDATE community_live_room_participants
    SET 
        is_hand_raised = NOT v_hand_raised,
        hand_raised_at = (CASE WHEN NOT v_hand_raised THEN now() ELSE NULL END)
    WHERE room_id = p_room_id AND user_id = v_user;

    RETURN jsonb_build_object('hand_raised', NOT v_hand_raised);
END;
$$;

-- 9d. Toggle Reminder for Scheduled Space
CREATE OR REPLACE FUNCTION toggle_live_room_reminder(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_exists BOOLEAN;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM community_live_room_reminders
        WHERE room_id = p_room_id AND user_id = v_user
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM community_live_room_reminders
        WHERE room_id = p_room_id AND user_id = v_user;
        RETURN jsonb_build_object('reminder_set', false);
    ELSE
        INSERT INTO community_live_room_reminders (room_id, user_id)
        VALUES (p_room_id, v_user);
        RETURN jsonb_build_object('reminder_set', true);
    END IF;
END;
$$;

-- 9e. Vote in Live Room Sentiment Poll
CREATE OR REPLACE FUNCTION vote_live_room_poll(
    p_room_id UUID,
    p_vote TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_room RECORD;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_vote NOT IN ('bullish', 'bearish') THEN
        RAISE EXCEPTION 'Invalid vote: must be bullish or bearish';
    END IF;

    IF p_vote = 'bullish' THEN
        UPDATE community_live_rooms
        SET poll_bullish_votes = poll_bullish_votes + 1
        WHERE id = p_room_id
        RETURNING poll_bullish_votes, poll_bearish_votes INTO v_room;
    ELSE
        UPDATE community_live_rooms
        SET poll_bearish_votes = poll_bearish_votes + 1
        WHERE id = p_room_id
        RETURNING poll_bullish_votes, poll_bearish_votes INTO v_room;
    END IF;

    RETURN jsonb_build_object(
        'bullish_votes', v_room.poll_bullish_votes,
        'bearish_votes', v_room.poll_bearish_votes
    );
END;
$$;


-- 10. Row Level Security Policies
-- ---------------------------------------------------------------------------
ALTER TABLE community_live_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_live_room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_live_room_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_live_room_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_live_room_question_upvotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_live_room_reminders ENABLE ROW LEVEL SECURITY;

-- 10a. Rooms Policies
CREATE POLICY "Public can view live and scheduled rooms"
    ON community_live_rooms FOR SELECT
    USING (true);

CREATE POLICY "Traders can create live spaces"
    ON community_live_rooms FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Host can update own live space"
    ON community_live_rooms FOR UPDATE
    TO authenticated
    USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Host can end/delete own live space"
    ON community_live_rooms FOR DELETE
    TO authenticated
    USING (auth.uid() = host_id);

-- 10b. Participant Policies
CREATE POLICY "Public can view room participants"
    ON community_live_room_participants FOR SELECT
    USING (true);

CREATE POLICY "Traders can manage own participant state"
    ON community_live_room_participants FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 10c. Messages Policies
CREATE POLICY "Public can read live room chat"
    ON community_live_room_messages FOR SELECT
    USING (true);

CREATE POLICY "Participants can post live room chat"
    ON community_live_room_messages FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = sender_id);

-- 10d. Questions Policies
CREATE POLICY "Public can read questions"
    ON community_live_room_questions FOR SELECT
    USING (true);

CREATE POLICY "Participants can submit questions"
    ON community_live_room_questions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors and hosts can update questions"
    ON community_live_room_questions FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = author_id OR 
        EXISTS (
            SELECT 1 FROM community_live_rooms 
            WHERE id = room_id AND host_id = auth.uid()
        )
    );

CREATE POLICY "Traders can upvote questions"
    ON community_live_room_question_upvotes FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 10e. Reminders Policies
CREATE POLICY "Users can manage own reminders"
    ON community_live_room_reminders FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMIT;
