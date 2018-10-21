class GenerateAvionicsMatchRecord
  include Sidekiq::Worker
  sidekiq_options queue: :amr_records
  def perform(avionic)
    if AvionicsMatchRecord.where(given_name: avionic).first.nil?
      amr = AvionicsMatchRecord.new(given_name: avionic, name_hit_count: 0, candidate_vote_list: {}, nontrivial_candidates: AvionicDisambiguator.disambiguation_candidates(avionic))
      amr.save!
    else
      amr = AvionicsMatchRecord.where(given_name: avionic).first
      # amr.nontrivial_candidates = AvionicDisambiguator.disambiguation_candidates(avionic)
      amr.name_hit_count ||= 0
      amr.name_hit_count += 1
      amr.save!
    end
  end
end