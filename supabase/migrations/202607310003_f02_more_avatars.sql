-- Extend the curated F02 avatar set without changing existing selections.
alter table public.profiles drop constraint if exists profiles_avatar_key_check;
alter table public.profiles add constraint profiles_avatar_key_check
  check (avatar_key in (
    'sprout', 'rocket', 'star', 'fox', 'panda', 'dino', 'unicorn',
    'robot', 'butterfly', 'koala', 'cat', 'soccer', 'artist'
  ));
