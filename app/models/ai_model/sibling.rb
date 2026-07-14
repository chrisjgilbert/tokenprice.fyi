# A compact descriptor of one of a model's provider-siblings, handed to the
# description generator so it can position the model within the lineup — a newer
# step up, a smaller/faster tier, or a model superseded by a later release.
# Built by AiModel#sibling_lineup and rendered into the prompt by
# AiModel::Description; deliberately lean (name, when it launched, a one-line
# identity) to keep the added prompt cheap.
class AiModel
  Sibling = Data.define(:name, :released_on, :summary) do
    def to_prompt_line
      head = released_on ? "#{name} (released #{released_on.strftime('%Y-%m')})" : name
      summary.present? ? "#{head}: #{summary}" : head
    end
  end
end
