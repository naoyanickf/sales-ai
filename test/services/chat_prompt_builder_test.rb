require "test_helper"

class ChatPromptBuilderTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Prompt Lab", uuid: SecureRandom.uuid)
    @user = User.create!(
      email: "user-#{SecureRandom.uuid}@example.com",
      password: "Password!1",
      password_confirmation: "Password!1",
      confirmed_at: Time.current
    )
    WorkspaceUser.create!(workspace: @workspace, user: @user, role: :admin)
    @product = Product.create!(name: "GigaCC", workspace: @workspace, category: "Storage")
    @chat = Chat.create!(workspace: @workspace, user: @user, product: @product)
  end

  test "build returns structured prompt with general intent" do
    @chat.messages.create!(role: :user, content: "こんにちは、今日も頑張りましょう。")
    @chat.messages.create!(role: :assistant, content: "ご相談内容をお聞かせください。")
    @chat.messages.create!(role: :user, content: "雑談したいだけです。")

    product = @chat.product
    IntentClassifier.stub(:call, ChatPromptBuilder::INTENT_GENERAL) do
      product.stub(:query_gemini_rag, ->(_) { raise "should not be called" }) do
        prompt = ChatPromptBuilder.build(chat: @chat)
        assert_equal 3, prompt.length

        system_message = prompt.first
        assert_equal "system", system_message[:role]
        assert_includes system_message[:content], "B2B営業アシスタント"

        context_message = prompt[1]
        assert_equal "system", context_message[:role]
        assert_includes context_message[:content], "Product Knowledge"
        assert_includes context_message[:content], "会話履歴"
        assert_includes context_message[:content], "User:"

        latest_user = prompt.last
        assert_equal "user", latest_user[:role]
        assert_equal "雑談したいだけです。", latest_user[:content]
      end
    end
  end

  test "build embeds product rag summary when intent is product" do
    @chat.messages.create!(role: :user, content: "最初の質問です。")
    @chat.messages.create!(role: :assistant, content: "ご質問ありがとうございます。")
    @chat.messages.create!(role: :user, content: "料金プランを教えてください。")

    response = {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              { "text" => "料金プラン: Basic 100IDで月額10万円。" },
              { "text" => "契約期間: 12ヶ月から。サポート込み。" }
            ]
          },
          "groundingMetadata" => {
            "groundingChunks" => [
              { "id" => "doc-1" }
            ]
          }
        }
      ]
    }

    product = @chat.product
    IntentClassifier.stub(:call, ->(*) { raise "IntentClassifier should not be called when rule-based intent matches" }) do
      product.stub(:query_gemini_rag, response) do
        prompt = ChatPromptBuilder.build(chat: @chat)

        context_message = prompt[1]
        assert_includes context_message[:content], "料金プラン"
        assert_includes context_message[:content], "Product Knowledge"
        assert_equal "user", prompt.last[:role]
        assert_equal "料金プランを教えてください。", prompt.last[:content]
      end
    end
  end
end
